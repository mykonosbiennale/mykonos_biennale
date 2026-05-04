defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Merge do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, EntityMedia}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:duplicate_groups, [])
      |> assign(:selected_ids, MapSet.new())
      |> assign(:group_mode, "broad")
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:total_pages, 1)
      |> assign(:merged_count, 0)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    duplicate_groups = load_duplicate_groups(socket.assigns.group_mode)
    total_pages = max(1, ceil(length(duplicate_groups) / socket.assigns.per_page))
    {:noreply, assign(socket, duplicate_groups: duplicate_groups, total_pages: total_pages)}
  end

  @impl true
  def handle_event("set_group_mode", %{"mode" => mode}, socket)
      when mode in ["broad", "narrow"] do
    duplicate_groups = load_duplicate_groups(mode)

    {:noreply,
     socket
     |> assign(:group_mode, mode)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:duplicate_groups, duplicate_groups)}
  end

  defp load_duplicate_groups(mode) do
    ae_rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    ap_rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if ae_rt == nil or ap_rt == nil do
      []
    else
      artwork_event_rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^ae_rt.id,
            select: %{artwork_id: r.subject_id, event_id: r.object_id}
        )

      artwork_participant_rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^ap_rt.id,
            select: %{artwork_id: r.subject_id, participant_id: r.object_id}
        )

      ap_map = Enum.group_by(artwork_participant_rels, & &1.artwork_id, & &1.participant_id)

      artwork_ids =
        (Enum.map(artwork_event_rels, & &1.artwork_id) ++
           Enum.map(artwork_participant_rels, & &1.artwork_id))
        |> Enum.uniq()

      artworks =
        Repo.all(from e in Entity, where: e.id in ^artwork_ids)
        |> Enum.into(%{}, fn e -> {e.id, e} end)

      artwork_event_rels
      |> Enum.flat_map(fn %{artwork_id: aid, event_id: eid} ->
        pids = Map.get(ap_map, aid, [])

        for pid <- pids do
          artwork = Map.get(artworks, aid)

          if artwork do
            title_slug = slugify(artwork.fields["title"] || "")
            {eid, pid, title_slug, artwork}
          else
            nil
          end
        end
        |> Enum.reject(&is_nil/1)
      end)
      |> Enum.group_by(fn {eid, pid, title_slug, _} ->
        case mode do
          "broad" -> {eid, pid}
          "narrow" -> {eid, pid, title_slug}
        end
      end)
      |> Enum.filter(fn {_key, items} -> length(items) > 1 end)
      |> Enum.map(fn {key, items} ->
        artwork_entities = items |> Enum.map(&elem(&1, 3)) |> Enum.uniq_by(& &1.id)

        {eid, pid} =
          case key do
            {e, p} -> {e, p}
            {e, p, _} -> {e, p}
          end

        event = Repo.get(Entity, eid)
        participant = Repo.get(Entity, pid)

        artwork_entries =
          Enum.map(artwork_entities, fn a ->
            media = Content.list_media_for_entity(a)
            %{artwork: a, media: media}
          end)

        %{
          event: event,
          participant: participant,
          entries: artwork_entries
        }
      end)
      |> Enum.sort_by(fn g ->
        {g.participant.fields["last_name"] || "", g.participant.fields["first_name"] || "",
         g.event.fields["title"] || ""}
      end)
    end
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    selected = socket.assigns.selected_ids

    new_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected)}
  end

  def handle_event("merge_selected", _, socket) do
    groups = socket.assigns.duplicate_groups
    selected = socket.assigns.selected_ids

    {merged, new_groups} =
      Enum.reduce(groups, {0, []}, fn group, {count, acc} ->
        group_ids = Enum.map(group.entries, & &1.artwork.id)
        selected_in_group = group_ids |> Enum.filter(&MapSet.member?(selected, &1))

        cond do
          length(group.entries) < 2 ->
            {count, [group | acc]}

          length(selected_in_group) == 0 ->
            {count, [group | acc]}

          true ->
            survivor_id = hd(selected_in_group)
            to_merge = Enum.reject(group.entries, fn e -> e.artwork.id == survivor_id end)

            survivor_entry = Enum.find(group.entries, &(&1.artwork.id == survivor_id))

            merge_artworks!(survivor_entry, to_merge)

            new_entries = [
              %{
                artwork: Repo.get!(Entity, survivor_id),
                media: Content.list_media_for_entity(Repo.get!(Entity, survivor_id))
              }
            ]

            new_group = %{group | entries: new_entries}

            if length(new_entries) > 1 do
              {count + 1, [new_group | acc]}
            else
              {count + 1, acc}
            end
        end
      end)

    {:noreply,
     socket
     |> assign(:merged_count, merged)
     |> assign(:duplicate_groups, new_groups)
     |> assign(:selected_ids, MapSet.new())}
  end

  defp merge_artworks!(survivor_entry, to_merge) do
    survivor = survivor_entry.artwork

    for entry <- to_merge do
      duplicate = entry.artwork
      duplicate_media = entry.media

      for media <- duplicate_media do
        caption =
          if media.caption in [nil, ""], do: duplicate.fields["title"], else: media.caption

        alt_text =
          if media.alt_text in [nil, ""],
            do: duplicate.fields["description"],
            else: media.alt_text

        {:ok, updated_media} =
          Content.update_media(media, %{
            caption: caption,
            alt_text: alt_text
          })

        Content.attach_media_to_entity(survivor, updated_media)
      end

      Repo.delete_all(
        from em in EntityMedia,
          where: em.entity_id == ^duplicate.id
      )

      unless survivor.fields["description"] not in [nil, ""] do
        if duplicate.fields["description"] not in [nil, ""] do
          survivor
          |> Ecto.Changeset.change(
            fields: Map.put(survivor.fields, "description", duplicate.fields["description"])
          )
          |> Repo.update!()
        end
      end

      Repo.delete_all(
        from r in Relationship,
          where: r.subject_id == ^duplicate.id or r.object_id == ^duplicate.id
      )

      Content.delete_entity(duplicate)
    end
  end

  defp pfield(entity, key, default \\ nil)

  defp pfield(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp first_media([]), do: nil

  defp first_media([%{source_type: "upload", source_path: path} | _]) when is_binary(path),
    do: %{source_type: "upload", source_path: path}

  defp first_media([%{source_type: "url", source_url: url} | _]) when is_binary(url),
    do: %{source_type: "url", source_url: url}

  defp first_media([_ | rest]), do: first_media(rest)
  defp first_media(_), do: nil

  defp slugify(nil), do: ""

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[\s_]+/u, "-")
    |> String.trim("-")
  end
end
