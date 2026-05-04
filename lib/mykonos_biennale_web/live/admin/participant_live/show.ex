defmodule MykonosBiennaleWeb.Admin.ParticipantLive.Show do
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
    participant = Content.get_participant!(id)
    headshot = get_headshot(participant)
    artworks_by_event = get_artworks_grouped_by_event(participant)
    events = get_participant_events(participant)

    {:noreply,
     socket
     |> assign(:page_title, pfield(participant, "name") || "Participant ##{participant.id}")
     |> assign(:participant, participant)
     |> assign(:headshot, headshot)
     |> assign(:artworks_by_event, artworks_by_event)
     |> assign(:events, events)}
  end

  defp pfield(%Entity{fields: fields}, key, default \\ nil) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp get_headshot(participant) do
    media = Content.list_media_for_entity(participant)
    Enum.find(media, fn m -> m.source_type in ["upload", "url"] end)
  end

  defp get_artworks_grouped_by_event(participant) do
    ap_rt = Repo.get_by!(RelationshipType, slug: "artwork_participant")
    ae_rt = Repo.get_by!(RelationshipType, slug: "artwork_event")

    participant_rels =
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^participant.id and r.relationship_type_id == ^ap_rt.id,
          select: r.subject_id
      )

    if participant_rels == [] do
      []
    else
      artwork_event_rels =
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^participant_rels and r.relationship_type_id == ^ae_rt.id,
            preload: [:object]
        )

      artwork_ids = Enum.map(participant_rels, & &1)

      artworks =
        Repo.all(
          from e in Entity,
            where: e.id in ^artwork_ids,
            order_by: [desc: fragment("? ->> ?", e.fields, "date")]
        )
        |> Enum.map(fn artwork ->
          media = Content.list_media_for_entity(artwork)
          {artwork, media}
        end)
        |> Enum.into(%{}, fn {artwork, media} -> {artwork.id, {artwork, media}} end)

      artwork_event_rels
      |> Enum.group_by(fn rel -> rel.object end)
      |> Enum.map(fn {event, rels} ->
        artwork_entries =
          rels
          |> Enum.map(fn rel -> Map.get(artworks, rel.subject_id) end)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(fn {a, _} -> a.fields["date"] || "" end, :desc)

        {event, artwork_entries}
      end)
      |> Enum.sort_by(fn {event, _} -> event.fields["title"] || "" end)
    end
  end

  defp get_participant_events(participant) do
    ap_rt = Repo.get_by!(RelationshipType, slug: "artwork_participant")
    ae_rt = Repo.get_by!(RelationshipType, slug: "artwork_event")

    artwork_ids =
      Repo.all(
        from r in Relationship,
          where: r.object_id == ^participant.id and r.relationship_type_id == ^ap_rt.id,
          select: r.subject_id
      )

    if artwork_ids == [] do
      []
    else
      event_ids =
        Repo.all(
          from r in Relationship,
            where: r.subject_id in ^artwork_ids and r.relationship_type_id == ^ae_rt.id,
            select: r.object_id
        )
        |> Enum.uniq()

      if event_ids == [] do
        []
      else
        Repo.all(from e in Entity, where: e.id in ^event_ids)
        |> Enum.sort_by(& &1.fields["title"])
      end
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
        participant = socket.assigns.participant

        participant
        |> Ecto.Changeset.change(fields: new_fields)
        |> Repo.update!()

        {:noreply, assign(socket, :participant, %{participant | fields: new_fields})}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
