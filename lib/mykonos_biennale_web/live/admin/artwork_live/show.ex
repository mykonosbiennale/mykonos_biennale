defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Show do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Media, RelationshipType}
  alias MykonosBiennale.Workers.MediaProcess

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_tab, "default")
     |> assign(:move_media_id, nil)
     |> assign(:move_search, "")
     |> assign(:move_results, [])}
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
     |> assign(:media, media)
     |> assign(:move_media_id, nil)
     |> assign(:move_search, "")
     |> assign(:move_results, [])}
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

  def handle_event("start_move_media", %{"media-id" => media_id}, socket) do
    {:noreply,
     socket
     |> assign(:move_media_id, String.to_integer(media_id))
     |> assign(:move_search, "")
     |> assign(:move_results, [])}
  end

  def handle_event("cancel_move_media", _, socket) do
    {:noreply,
     socket
     |> assign(:move_media_id, nil)
     |> assign(:move_search, "")
     |> assign(:move_results, [])}
  end

  def handle_event("search_artwork", %{"search" => search}, socket) do
    results =
      if String.trim(search) == "" do
        []
      else
        pattern = "%#{String.downcase(search)}%"

        Repo.all(
          from e in Entity,
            where:
              e.type == "artwork" and
                e.id != ^socket.assigns.artwork.id and
                (ilike(fragment("lower(?)", e.identity), ^pattern) or
                   ilike(fragment("lower(?->>'title')", e.fields), ^pattern)),
            limit: 10,
            select: {e.id, e.identity, fragment("?->>'date'", e.fields)}
        )
      end

    {:noreply,
     socket
     |> assign(:move_search, search)
     |> assign(:move_results, results)}
  end

  def handle_event("move_media", %{"target-id" => target_id_str}, socket) do
    target_id = String.to_integer(target_id_str)
    media_id = socket.assigns.move_media_id
    artwork = socket.assigns.artwork

    media = Repo.get!(Media, media_id)
    target = Content.get_artwork!(target_id)

    {:ok, :detached} = Content.detach_media_from_entity(artwork, media)
    {:ok, _} = Content.attach_media_to_entity(target, media)

    media_list = Content.list_media_for_entity(artwork)

    {:noreply,
     socket
     |> assign(:media, media_list)
     |> assign(:move_media_id, nil)
     |> assign(:move_search, "")
     |> assign(:move_results, [])
     |> put_flash(:info, "Media moved to #{target.identity}")}
  end

  def handle_event("remove_media", %{"media-id" => media_id}, socket) do
    artwork = socket.assigns.artwork
    media = Repo.get!(Media, String.to_integer(media_id))
    {:ok, :detached} = Content.detach_media_from_entity(artwork, media)

    media_list = Content.list_media_for_entity(artwork)

    {:noreply,
     socket
     |> assign(:media, media_list)
     |> put_flash(:info, "Media removed")}
  end

  def handle_event("rotate_media", %{"media-id" => media_id, "degrees" => degrees}, socket) do
    media = Repo.get!(Media, String.to_integer(media_id))
    MediaProcess.enqueue_rotate(media.id, String.to_integer(degrees))

    {:noreply,
     put_flash(
       socket,
       :info,
       "Rotation #{degrees}° queued for #{media.original_name || media.caption}"
     )}
  end

  @impl true

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

  defp media_thumb(%Media{source_type: "upload"} = m) do
    MykonosBiennale.Uploads.media_url(m, size: "thumb")
  end

  defp media_thumb(%Media{source_type: "url", source_url: url}) when is_binary(url), do: url
  defp media_thumb(_), do: nil
end
