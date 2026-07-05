defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Search

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Artworks")
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:sort_by, :date)
     |> assign(:sort_dir, :desc)
     |> assign(:creators_map, %{})
     |> assign(:events_map, %{})
     |> assign(:media_map, %{})
     |> assign(:artworks_loaded, false)
     |> stream(:artworks, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "date") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "desc") |> String.to_atom()

    {artworks, total_count} =
      Content.list_artworks_paginated(page, @per_page, search,
        sort_by: sort_by,
        sort_dir: sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    artwork_ids = Enum.map(artworks, & &1.id)

    socket =
      if !socket.assigns.artworks_loaded do
        socket |> assign(:artworks_loaded, true)
      else
        socket
      end

    return_path =
      if socket.assigns.live_action == :index do
        "/admin/artworks?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
      else
        socket.assigns[:return_path] || "/admin/artworks"
      end

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:return_path, return_path)
      |> assign(:creators_map, batch_load_creators(artwork_ids))
      |> assign(:events_map, batch_load_events(artwork_ids))
      |> assign(:media_map, batch_load_first_media(artwork_ids))
      |> stream(:artworks, artworks, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp batch_load_creators([]), do: %{}

  defp batch_load_creators(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")
    if rt == nil, do: %{}, else: do_batch_load_creators(rt.id, artwork_ids)
  end

  defp do_batch_load_creators(rt_id, artwork_ids) do
    Repo.all(
      from r in Relationship,
        where: r.relationship_type_id == ^rt_id and r.subject_id in ^artwork_ids,
        preload: [:object]
    )
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

  defp batch_load_events([]), do: %{}

  defp batch_load_events(artwork_ids) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")
    if rt == nil, do: %{}, else: do_batch_load_events(rt.id, artwork_ids)
  end

  defp do_batch_load_events(rt_id, artwork_ids) do
    Repo.all(
      from r in Relationship,
        where: r.relationship_type_id == ^rt_id and r.subject_id in ^artwork_ids,
        preload: [:object]
    )
    |> Enum.group_by(& &1.subject_id, fn r ->
      title = if r.object, do: r.object.fields["title"], else: "Unknown"
      %{id: r.object_id, title: title}
    end)
  end

  defp batch_load_first_media([]), do: %{}

  defp batch_load_first_media(artwork_ids) do
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
    |> Enum.group_by(& &1.entity_id)
    |> Enum.into(%{}, fn {eid, items} ->
      first =
        Enum.find(items, &(&1.source_type == "upload" and is_binary(&1.source_path))) ||
          Enum.find(items, &(&1.source_type == "url" and is_binary(&1.source_url)))

      {eid, first}
    end)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Artwork") |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket |> assign(:page_title, "Show Artwork") |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Artwork")
    |> assign(:artwork, %Content.Entity{type: "artwork", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Artworks") |> assign(:artwork, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, _artwork}},
        socket
      ) do
    page = socket.assigns.current_page

    {artworks, total_count} =
      Content.list_artworks_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    artwork_ids = Enum.map(artworks, & &1.id)

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:creators_map, batch_load_creators(artwork_ids))
     |> assign(:events_map, batch_load_events(artwork_ids))
     |> assign(:media_map, batch_load_first_media(artwork_ids))
     |> stream(:artworks, artworks, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    artwork = Content.get_artwork!(id)
    {:ok, _} = Content.delete_artwork(artwork)

    page = socket.assigns.current_page

    {artworks, total_count} =
      Content.list_artworks_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    artwork_ids = Enum.map(artworks, & &1.id)

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:creators_map, batch_load_creators(artwork_ids))
     |> assign(:events_map, batch_load_events(artwork_ids))
     |> assign(:media_map, batch_load_first_media(artwork_ids))
     |> stream(:artworks, artworks, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {artworks, total_count} =
      Content.list_artworks_paginated(1, @per_page, term,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    artwork_ids = Enum.map(artworks, & &1.id)

    {:noreply,
     socket
     |> assign(:search, term)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:creators_map, batch_load_creators(artwork_ids))
     |> assign(:events_map, batch_load_events(artwork_ids))
     |> assign(:media_map, batch_load_first_media(artwork_ids))
     |> stream(:artworks, artworks, reset: true)
     |> push_patch(
       to: patch_path("/admin/artworks", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {artworks, total_count} =
      Content.list_artworks_paginated(1, @per_page, "",
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))
    artwork_ids = Enum.map(artworks, & &1.id)

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> assign(:creators_map, batch_load_creators(artwork_ids))
     |> assign(:events_map, batch_load_events(artwork_ids))
     |> assign(:media_map, batch_load_first_media(artwork_ids))
     |> stream(:artworks, artworks, reset: true)
     |> push_patch(
       to: patch_path("/admin/artworks", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  defp patch_path(base, page, sort_by, sort_dir) do
    "#{base}?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
