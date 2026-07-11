defmodule MykonosBiennaleWeb.Admin.FilmLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Films & Videos")
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:sort_by, :ref)
     |> assign(:sort_dir, :asc)
     |> assign(:poster_map, %{})
     |> assign(:events_map, %{})
     |> assign(:film, nil)
     |> stream(:films, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "ref") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "asc") |> String.to_atom()

    {films, total_count} =
      Content.list_films_paginated(page, @per_page, search, sort_by: sort_by, sort_dir: sort_dir)

    total_pages = max(1, ceil(total_count / @per_page))
    film_ids = Enum.map(films, & &1.id)

    return_path =
      if socket.assigns.live_action == :index do
        "/admin/films?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
      else
        socket.assigns[:return_path] || "/admin/films"
      end

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:return_path, return_path)
      |> assign(:poster_map, batch_load_posters(film_ids))
      |> assign(:events_map, batch_load_events(film_ids))
      |> stream(:films, films, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Film") |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :new, params) do
    default_event_id = Map.get(params, "event_id", "")

    socket
    |> assign(:page_title, "New Film")
    |> assign(:film, %Entity{type: "Short Film", fields: %{}})
    |> assign(:default_event_id, default_event_id)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Film") |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Films & Videos") |> assign(:film, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.FilmLive.FormComponent, {:saved, _film}}, socket) do
    page = socket.assigns.current_page

    {films, total_count} =
      Content.list_films_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    film_ids = Enum.map(films, & &1.id)

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:poster_map, batch_load_posters(film_ids))
     |> assign(:events_map, batch_load_events(film_ids))
     |> stream(:films, films, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    film = Content.Film.get!(id)
    {:ok, _} = Content.Film.delete(film)

    page = socket.assigns.current_page

    {films, total_count} =
      Content.list_films_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    film_ids = Enum.map(films, & &1.id)

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:poster_map, batch_load_posters(film_ids))
     |> assign(:events_map, batch_load_events(film_ids))
     |> stream(:films, films, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {films, total_count} =
      Content.list_films_paginated(1, @per_page, term,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    film_ids = Enum.map(films, & &1.id)

    {:noreply,
     socket
     |> assign(:search, term)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:poster_map, batch_load_posters(film_ids))
     |> assign(:events_map, batch_load_events(film_ids))
     |> stream(:films, films, reset: true)
     |> push_patch(
       to: patch_path("/admin/films", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {films, total_count} =
      Content.list_films_paginated(1, @per_page, "",
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    film_ids = Enum.map(films, & &1.id)

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:poster_map, batch_load_posters(film_ids))
     |> assign(:events_map, batch_load_events(film_ids))
     |> stream(:films, films, reset: true)
     |> push_patch(
       to: patch_path("/admin/films", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end


  defp patch_path(base, page, sort_by, sort_dir) do
    "#{base}?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
  end

  defp batch_load_posters(film_ids) do
    Repo.all(
      from em in EntityMedia,
        where: em.entity_id in ^film_ids,
        join: m in Media,
        on: m.id == em.media_id,
        where:
          fragment(
            "? ->> 'is_poster' = 'true' or ? ->> 'role' = 'poster'",
            em.metadata,
            em.metadata
          ),
        order_by: [em.entity_id, em.position],
        select: %{
          entity_id: em.entity_id,
          source_type: m.source_type,
          source_path: m.source_path,
          source_url: m.source_url
        }
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
