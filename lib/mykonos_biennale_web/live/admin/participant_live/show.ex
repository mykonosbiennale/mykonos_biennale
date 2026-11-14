defmodule MykonosBiennaleWeb.Admin.ParticipantLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Content.RelationshipType
  alias MykonosBiennale.Repo

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
    relationships = list_relationships(participant)

    socket =
      socket
      |> assign(:page_title, pfield(participant, "name") || "Participant ##{participant.id}")
      |> assign(:participant, participant)
      |> assign(:headshot, headshot)
      |> assign(:artworks_by_event, artworks_by_event)
      |> assign(:events, events)
      |> assign(:relationships, relationships)
      |> assign(:artwork_search, "")
      |> assign(:artwork_results, [])

    socket =
      case socket.assigns.live_action do
        :new_artwork ->
          socket
          |> assign(:artwork, %Content.Entity{type: "artwork", fields: %{}})
          |> assign(:return_path, "/admin/participants/#{participant.id}")

        _ ->
          socket
          |> assign(:artwork, nil)
          |> assign(:return_path, "/admin/participants/#{participant.id}")
      end

    {:noreply, socket}
  end

  defp pfield(entity, key, default \\ nil)

  defp pfield(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp list_relationships(participant) do
    Repo.all(
      from r in Relationship,
        where: r.subject_id == ^participant.id or r.object_id == ^participant.id,
        preload: [:subject, :object, :relationship_type]
    )
    |> Enum.sort_by(fn r -> {r.relationship_type.slug, r.subject_id != participant.id} end)
  end

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
      |> Enum.map(fn {event, rels} -> {event, group_artwork_entries(rels, artworks)} end)
      |> Enum.sort_by(fn {event, _} -> event.fields["title"] || "" end)
    end
  end

  defp group_artwork_entries(rels, artworks) do
    rels
    |> Enum.map(fn rel -> Map.get(artworks, rel.subject_id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {a, _} -> a.fields["date"] || "" end, :desc)
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

  def handle_info(
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:flash, kind, message}},
        socket
      ) do
    {:noreply, put_flash(socket, kind, message)}
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

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, artwork}},
        socket
      ) do
    participant = socket.assigns.participant

    case Content.attach_participant_to_artwork(artwork, participant, "creator") do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Artwork created and linked to #{pfield(participant, "name")}")
         |> assign(:artworks_by_event, get_artworks_grouped_by_event(participant))
         |> assign(:events, get_participant_events(participant))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Artwork created but could not link: #{inspect(reason)}")
         |> assign(:artworks_by_event, get_artworks_grouped_by_event(participant))
         |> assign(:events, get_participant_events(participant))}
    end
  end
end
