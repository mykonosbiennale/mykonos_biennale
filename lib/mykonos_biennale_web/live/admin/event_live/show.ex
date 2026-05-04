defmodule MykonosBiennaleWeb.Admin.EventLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:active_tab, "default")}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    event = Content.get_event!(id)
    biennale = get_event_biennale(event)
    project = get_event_project(event)
    artworks = get_event_artworks(event)

    {:noreply,
     socket
     |> assign(:page_title, efield(event, "title") || "Event ##{event.id}")
     |> assign(:event, event)
     |> assign(:biennale, biennale)
     |> assign(:project, project)
     |> assign(:artworks, artworks)}
  end

  defp efield(%Entity{fields: fields}, key, default \\ nil) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp efield(_, _key, default), do: default

  defp get_event_biennale(event) do
    rt = Repo.get_by(RelationshipType, slug: "biennale_event")

    if rt do
      case Repo.one(
             from r in Relationship,
               where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
               limit: 1,
               select: r.object_id
           ) do
        nil -> nil
        biennale_id -> Repo.get(Entity, biennale_id)
      end
    end
  end

  defp get_event_project(event) do
    rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt do
      case Repo.one(
             from r in Relationship,
               where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
               limit: 1,
               select: r.object_id
           ) do
        nil -> nil
        project_id -> Repo.get(Entity, project_id)
      end
    end
  end

  defp get_event_artworks(event) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      artwork_ids =
        Repo.all(
          from r in Relationship,
            where: r.object_id == ^event.id and r.relationship_type_id == ^rt.id,
            select: r.subject_id
        )

      if artwork_ids == [] do
        []
      else
        artworks =
          Repo.all(
            from e in Entity,
              where: e.id in ^artwork_ids,
              order_by: [desc: fragment("? ->> ?", e.fields, "date")]
          )

        media_by_id = batch_media(artwork_ids)
        creators_by_id = batch_creators(artwork_ids)

        Enum.map(artworks, fn artwork ->
          {artwork, Map.get(media_by_id, artwork.id, []), Map.get(creators_by_id, artwork.id, [])}
        end)
      end
    else
      []
    end
  end

  defp batch_media(artwork_ids) do
    records =
      Repo.all(
        from em in Content.EntityMedia,
          where: em.entity_id in ^artwork_ids,
          order_by: em.position,
          preload: [:media]
      )

    Enum.group_by(records, & &1.entity_id, & &1.media)
  end

  defp batch_creators(artwork_ids) do
    ap_rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if ap_rt do
      rels =
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^artwork_ids and r.relationship_type_id == ^ap_rt.id,
            preload: [:object]
        )

      rels
      |> Enum.group_by(& &1.subject_id)
      |> Enum.into(%{}, fn {artwork_id, rels} ->
        creators = rels |> Enum.map(& &1.object) |> Enum.reject(&is_nil/1)
        {artwork_id, creators}
      end)
    else
      %{}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_info({:fields_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_fields} ->
        event = socket.assigns.event

        event
        |> Ecto.Changeset.change(fields: new_fields)
        |> Repo.update!()

        {:noreply, assign(socket, :event, %{event | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
