defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Show do
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
    artwork = Content.get_artwork!(id) |> Repo.preload(as_subject: show_relationship_query())

    participants = list_linked_participants(artwork)
    events = list_linked_events(artwork)
    media = Content.list_media_for_entity(artwork)

    {:noreply,
     socket
     |> assign(:page_title, artwork.fields["title"] || "Artwork ##{artwork.id}")
     |> assign(:artwork, artwork)
     |> assign(:participants, participants)
     |> assign(:events, events)
     |> assign(:media, media)}
  end

  defp show_relationship_query do
    rt_ids =
      from rt in RelationshipType,
        where: rt.slug in ^["artwork_event", "artwork_participant"],
        select: rt.id

    from r in Content.Relationship,
      where: r.relationship_type_id in subquery(rt_ids),
      preload: [:object, :relationship_type]
  end

  defp list_linked_participants(artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      Repo.all(
        from r in Content.Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
    else
      []
    end
  end

  defp list_linked_events(artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      Repo.all(
        from r in Content.Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object]
      )
    else
      []
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_info({:fields_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_fields} ->
        artwork = socket.assigns.artwork

        artwork
        |> Ecto.Changeset.change(fields: new_fields)
        |> Repo.update!()

        {:noreply, assign(socket, :artwork, %{artwork | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Entity{}, _key, default), do: default
end
