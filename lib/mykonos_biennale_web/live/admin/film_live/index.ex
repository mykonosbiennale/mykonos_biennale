defmodule MykonosBiennaleWeb.Admin.FilmLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Search

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Films & Videos")
     |> assign(:search, "")
     |> assign(:poster_map, %{})
     |> assign(:events_map, %{})
     |> assign(:film, nil)
     |> stream(:films, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = load_films(socket)
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp load_films(socket) do
    films = list_films_filtered(socket.assigns.search)
    film_ids = Enum.map(films, & &1.id)

    socket
    |> assign(:poster_map, batch_load_posters(film_ids))
    |> assign(:events_map, batch_load_events(film_ids))
    |> stream(:films, films, reset: true)
  end

  defp list_films_filtered(""), do: Content.Film.list()
  defp list_films_filtered(term) do
    pattern = Search.entity_search_pattern(term)

    Repo.all(
      from e in Entity,
        where: e.type in ^@film_types,
        where: not is_nil(e.search_index) and like(e.search_index, ^pattern),
        order_by: [asc: fragment("? ->> ?", e.fields, "ref")]
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Film") |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :new, params) do
    default_event_id = Map.get(params, "event_id", "")
    socket |> assign(:page_title, "New Film") |> assign(:film, %Entity{type: "Short Film", fields: %{}}) |> assign(:default_event_id, default_event_id)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Film") |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Films & Videos") |> assign(:film, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.FilmLive.FormComponent, {:saved, _film}}, socket) do
    {:noreply, load_films(socket)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    film = Content.Film.get!(id)
    {:ok, _} = Content.Film.delete(film)
    {:noreply, load_films(socket)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> load_films()}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> load_films()}
  end

  defp batch_load_posters([]), do: %{}
  defp batch_load_posters(film_ids) do
    Repo.all(
      from em in EntityMedia,
        where: em.entity_id in ^film_ids,
        join: m in Media, on: m.id == em.media_id,
        where: fragment("? ->> 'is_poster' = 'true' or ? ->> 'role' = 'poster'", em.metadata, em.metadata),
        order_by: [em.entity_id, em.position],
        select: %{entity_id: em.entity_id, source_type: m.source_type, source_path: m.source_path, source_url: m.source_url}
    )
    |> Enum.group_by(& &1.entity_id)
    |> Enum.into(%{}, fn {eid, items} -> {eid, hd(items)} end)
  end

  defp batch_load_events(film_ids) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")
    if rt == nil or film_ids == [], do: %{}, else: do_batch_load_events(rt.id, film_ids)
  end

  defp do_batch_load_events(rt_id, film_ids) do
    Repo.all(
      from r in Relationship,
        where: r.relationship_type_id == ^rt_id and r.subject_id in ^film_ids,
        preload: [:object]
    )
    |> Enum.group_by(& &1.subject_id, fn r ->
      event = r.object
      title = if event, do: event.fields["title"], else: "Unknown"
      year = if event, do: event.fields["date"], else: nil
      %{id: r.object_id, title: title, year: year}
    end)
  end

  defp field(entity, key, default \\ nil)
  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end
  defp field(%Content.Entity{}, _key, default), do: default
end
