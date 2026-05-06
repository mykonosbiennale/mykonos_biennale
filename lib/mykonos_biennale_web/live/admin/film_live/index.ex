defmodule MykonosBiennaleWeb.Admin.FilmLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}

  @impl true
  def mount(_params, _session, socket) do
    films = Content.Film.list()
    film_ids = Enum.map(films, & &1.id)

    poster_map = batch_load_posters(film_ids)
    events_map = batch_load_events(film_ids)

    {:ok,
     socket
     |> assign(:page_title, "Films & Videos")
     |> assign(:poster_map, poster_map)
     |> assign(:events_map, events_map)
     |> assign(:film, nil)
     |> stream(:films, films)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Film")
    |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Film")
    |> assign(:film, Content.Film.get!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Films & Videos")
    |> assign(:film, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.FilmLive.FormComponent, {:saved, film}}, socket) do
    {:noreply, stream_insert(socket, :films, film)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    film = Content.Film.get!(id)
    {:ok, _} = Content.Film.delete(film)
    {:noreply, stream_delete(socket, :films, film)}
  end

  defp batch_load_posters(film_ids) do
    if film_ids == [] do
      %{}
    else
      ems =
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

      ems
      |> Enum.group_by(& &1.entity_id)
      |> Enum.into(%{}, fn {eid, items} -> {eid, hd(items)} end)
    end
  end

  defp batch_load_events(film_ids) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")

    if rt == nil or film_ids == [] do
      %{}
    else
      rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^rt.id and r.subject_id in ^film_ids,
            preload: [:object]
        )

      rels
      |> Enum.group_by(& &1.subject_id, fn r ->
        event = r.object
        title = if event, do: event.fields["title"], else: "Unknown"
        year = if event, do: event.fields["date"], else: nil
        %{id: r.object_id, title: title, year: year}
      end)
    end
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
