defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Merge do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Media, Relationship, RelationshipType, EntityMedia}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:duplicate_groups, [])
      |> assign(:all_groups, [])
      |> assign(:groups_loaded, false)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:group_mode, "narrow")
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:total_pages, 1)
      |> assign(:all_groups_count, 0)
      |> assign(:merged_count, 0)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")

    {all_groups, socket} =
      if socket.assigns.groups_loaded do
        {socket.assigns.all_groups, socket}
      else
        socket = assign(socket, :loading, true)
        groups = load_duplicate_groups(socket.assigns.group_mode)
        socket = assign(socket, :loading, false)
        {groups, socket}
      end

    total_pages = max(1, ceil(length(all_groups) / socket.assigns.per_page))
    page = min(page, total_pages)
    offset = (page - 1) * socket.assigns.per_page
    page_groups = Enum.slice(all_groups, offset, socket.assigns.per_page)

    {:noreply,
     socket
     |> assign(:all_groups, all_groups)
     |> assign(:duplicate_groups, page_groups)
     |> assign(:all_groups_count, length(all_groups))
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)
     |> assign(:groups_loaded, true)}
  rescue
    _ ->
      {:noreply, assign(socket, :loading, false)}
  end

  @impl true
  def handle_event("set_group_mode", %{"mode" => mode}, socket)
      when mode in ["broad", "narrow"] do
    {:noreply,
     socket
     |> assign(:group_mode, mode)
     |> assign(:groups_loaded, false)
     |> assign(:selected_ids, MapSet.new())
     |> push_patch(to: "/admin/artworks/merge?page=1")}
  end

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

    {merged, survivor_ids} =
      Enum.reduce(groups, {0, []}, fn group, {count, survivors} ->
        group_ids = Enum.map(group.entries, & &1.artwork.id)
        selected_in_group = group_ids |> Enum.filter(&MapSet.member?(selected, &1))

        if length(group.entries) >= 2 and selected_in_group != [] do
          survivor_id = hd(selected_in_group)
          to_merge = Enum.reject(group.entries, fn e -> e.artwork.id == survivor_id end)
          survivor_entry = Enum.find(group.entries, &(&1.artwork.id == survivor_id))
          merge_artworks!(survivor_entry, to_merge)
          {count + 1, [survivor_id | survivors]}
        else
          {count, survivors}
        end
      end)

    enqueue_reindex(survivor_ids)

    {:noreply,
     socket
     |> assign(:merged_count, merged)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:groups_loaded, false)
     |> push_patch(to: "/admin/artworks/merge?page=#{socket.assigns.page}")}
  end

  def handle_event("merge_all", _, socket) do
    all_groups = load_duplicate_groups(socket.assigns.group_mode)

    {merged, survivor_ids} =
      Enum.reduce(all_groups, {0, []}, fn group, {count, survivors} ->
        if length(group.entries) < 2 do
          {count, survivors}
        else
          sorted_entries = Enum.sort_by(group.entries, & &1.artwork.id)
          survivor_entry = hd(sorted_entries)
          to_merge = tl(sorted_entries)
          merge_artworks!(survivor_entry, to_merge)
          {count + 1, [survivor_entry.artwork.id | survivors]}
        end
      end)

    enqueue_reindex(survivor_ids)

    {:noreply,
     socket
     |> assign(:merged_count, merged)
     |> assign(:selected_ids, MapSet.new())
     |> assign(:groups_loaded, false)
     |> push_patch(to: "/admin/artworks/merge?page=1")}
  end

  defp enqueue_reindex([]), do: :ok

  defp enqueue_reindex(survivor_ids) do
    survivor_ids
    |> Enum.uniq()
    |> Enum.each(&MykonosBiennale.Workers.SearchReindex.enqueue_entity/1)
  end

  defp load_duplicate_groups(mode) do
    rt_slugs =
      Repo.all(
        from rt in RelationshipType, where: rt.slug in ~w(artwork_event artwork_participant)
      )
      |> Enum.into(%{}, &{&1.slug, &1.id})

    ae_rt_id = rt_slugs["artwork_event"]
    ap_rt_id = rt_slugs["artwork_participant"]

    if ae_rt_id == nil or ap_rt_id == nil do
      []
    else
      rels =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id in ^[ae_rt_id, ap_rt_id],
            select: {r.relationship_type_id, r.subject_id, r.object_id}
        )

      artwork_ids =
        rels |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

      artworks = Repo.all(from e in Entity, where: e.id in ^artwork_ids and e.type == "artwork")
      artwork_map = Enum.into(artworks, %{}, &{&1.id, &1})

      media_rows =
        Repo.all(
          from m in Media,
            join: em in EntityMedia,
            on: em.media_id == m.id,
            where: em.entity_id in ^artwork_ids,
            order_by: [em.entity_id, em.position],
            select: {em.entity_id, m.id, m.source_type, m.source_path, m.source_url}
        )

      media_by_artwork =
        Enum.reduce(media_rows, %{}, fn {eid, mid, st, sp, su}, acc ->
          Map.update(acc, eid, [{mid, st, sp, su}], &(&1 ++ [{mid, st, sp, su}]))
        end)

      linked_ids =
        rels
        |> Enum.flat_map(fn
          {rt_id, _, obj_id} when rt_id == ae_rt_id -> [obj_id]
          {rt_id, _, obj_id} when rt_id == ap_rt_id -> [obj_id]
          _ -> []
        end)
        |> Enum.uniq()

      linked = Repo.all(from e in Entity, where: e.id in ^linked_ids)
      linked_map = Enum.into(linked, %{}, &{&1.id, &1})

      ae_rels = Enum.filter(rels, fn {rt, _, _} -> rt == ae_rt_id end)
      ap_rels = Enum.filter(rels, fn {rt, _, _} -> rt == ap_rt_id end)

      ap_map = Enum.group_by(ap_rels, &elem(&1, 1), &elem(&1, 2))

      ae_rels
      |> Enum.flat_map(fn {_, aid, eid} ->
        pids = Map.get(ap_map, aid, [])

        for pid <- pids do
          artwork = Map.get(artwork_map, aid)

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

        event = Map.get(linked_map, eid)
        participant = Map.get(linked_map, pid)

        artwork_entries =
          Enum.map(artwork_entities, fn a ->
            %{artwork: a, media: Map.get(media_by_artwork, a.id, [])}
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

  defp merge_artworks!(survivor_entry, to_merge) do
    survivor = survivor_entry.artwork
    duplicate_ids = Enum.map(to_merge, & &1.artwork.id)

    all_dup_media =
      Enum.flat_map(to_merge, fn entry ->
        Enum.map(entry.media, fn {mid, st, sp, su} ->
          {entry.artwork.id, mid, st, sp, su}
        end)
      end)

    survivor_media_ids =
      Repo.all(
        from em in EntityMedia,
          where: em.entity_id == ^survivor.id,
          select: em.media_id
      )
      |> MapSet.new()

    new_media_links =
      all_dup_media
      |> Enum.reject(fn {_, mid, _, _, _} -> MapSet.member?(survivor_media_ids, mid) end)

    max_pos =
      Repo.one(
        from em in EntityMedia,
          where: em.entity_id == ^survivor.id,
          select: coalesce(max(em.position), -1)
      ) || -1

    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    {rows, _final_pos} =
      Enum.map_reduce(new_media_links, max_pos + 1, fn {_, mid, _, _, _}, pos ->
        {[
           entity_id: survivor.id,
           media_id: mid,
           position: pos,
           metadata: %{},
           inserted_at: now,
           updated_at: now
         ], pos + 1}
      end)

    if rows != [] do
      Repo.insert_all(EntityMedia, rows)
    end

    dup_description =
      Enum.find_value(to_merge, fn entry ->
        d = entry.artwork.fields["description"]
        if d in [nil, ""], do: nil, else: d
      end)

    if survivor.fields["description"] in [nil, ""] and dup_description do
      survivor
      |> Ecto.Changeset.change(fields: Map.put(survivor.fields, "description", dup_description))
      |> Repo.update!()
    end

    if duplicate_ids != [] do
      Repo.delete_all(from em in EntityMedia, where: em.entity_id in ^duplicate_ids)

      Repo.delete_all(
        from r in Relationship,
          where: r.subject_id in ^duplicate_ids or r.object_id in ^duplicate_ids
      )

      Repo.delete_all(from e in Entity, where: e.id in ^duplicate_ids)
    end
  end

  defp pfield(entity, key, default \\ nil)

  defp pfield(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp pfield(_, _key, default), do: default

  defp first_media([]), do: nil

  defp first_media([{_mid, source_type, source_path, source_url} | _]) do
    %{source_type: source_type, source_path: source_path, source_url: source_url}
  end

  defp first_media([_ | rest]), do: first_media(rest)

  defp media_thumb_url(%{source_type: "upload", source_path: path}) when is_binary(path) do
    MykonosBiennale.Uploads.media_url(%Media{source_type: "upload", source_path: path},
      size: "admin"
    )
  end

  defp media_thumb_url(%{source_type: "url", source_url: url}) when is_binary(url), do: url
  defp media_thumb_url(_), do: nil

  defp slugify(nil), do: ""

  defp slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/[\s_]+/u, "-")
    |> String.trim("-")
  end
end
