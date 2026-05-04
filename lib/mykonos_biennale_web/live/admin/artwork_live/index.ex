defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}

  @impl true
  def mount(_params, _session, socket) do
    artworks = Content.list_artworks()
    artwork_ids = Enum.map(artworks, & &1.id)

    creators_map = batch_load_creators(artwork_ids)
    events_map = batch_load_events(artwork_ids)
    media_map = batch_load_first_media(artwork_ids)

    {:ok,
     socket
     |> assign(:page_title, "Manage Artworks")
     |> assign(:creators_map, creators_map)
     |> assign(:events_map, events_map)
     |> assign(:media_map, media_map)
     |> stream(:artworks, artworks)}
  end

  defp batch_load_creators(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt == nil or artwork_ids == [] do
      %{}
    else
      rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^rt.id and r.subject_id in ^artwork_ids,
            preload: [:object]
        )

      rels
      |> Enum.group_by(& &1.subject_id, fn r ->
        name =
          case r.object do
            nil ->
              "Unknown"

            p ->
              p.fields["name"] ||
                "#{p.fields["first_name"] || ""} #{p.fields["last_name"] || ""}" |> String.trim()
          end

        %{id: r.object_id, name: name, role: r.fields["role"]}
      end)
    end
  end

  defp batch_load_events(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt == nil or artwork_ids == [] do
      %{}
    else
      rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^rt.id and r.subject_id in ^artwork_ids,
            preload: [:object]
        )

      rels
      |> Enum.group_by(& &1.subject_id, fn r ->
        title = if r.object, do: r.object.fields["title"], else: "Unknown"
        %{id: r.object_id, title: title}
      end)
    end
  end

  defp batch_load_first_media(artwork_ids) do
    if artwork_ids == [] do
      %{}
    else
      ems =
        Repo.all(
          from em in EntityMedia,
            where: em.entity_id in ^artwork_ids,
            join: m in Media,
            on: m.id == em.media_id,
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
      |> Enum.into(%{}, fn {eid, items} ->
        first =
          Enum.find(items, &(&1.source_type == "upload" and is_binary(&1.source_path))) ||
            Enum.find(items, &(&1.source_type == "url" and is_binary(&1.source_url)))

        {eid, first}
      end)
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Artwork")
    |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Artwork")
    |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Artwork")
    |> assign(:artwork, %Content.Entity{type: "artwork", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Artworks")
    |> assign(:artwork, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, artwork}},
        socket
      ) do
    {:noreply, stream_insert(socket, :artworks, artwork)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    artwork = Content.get_artwork!(id)
    {:ok, _} = Content.delete_artwork(artwork)

    {:noreply, stream_delete(socket, :artworks, artwork)}
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
