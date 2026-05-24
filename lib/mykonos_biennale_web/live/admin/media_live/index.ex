defmodule MykonosBiennaleWeb.Admin.MediaLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_dir, :desc)
     |> stream(:media_collection, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "inserted_at") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "desc") |> String.to_atom()

    {items, total_count} = Content.list_media_paginated(page, @per_page, search, sort_by: sort_by, sort_dir: sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:page_title, "Media Library")
      |> assign(:media, nil)
      |> stream(:media_collection, items, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Media") |> assign(:media, Content.get_media!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Media") |> assign(:media, %MykonosBiennale.Content.Media{})
  end

  defp apply_action(socket, :index, _params), do: socket

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.MediaLive.FormComponent, {:saved, media}}, socket) do
    page = socket.assigns.current_page
    {_items, total_count} = Content.list_media_paginated(page, @per_page, socket.assigns.search, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
     |> stream_insert(:media_collection, media)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media = Content.get_media!(id)
    {:ok, _} = Content.delete_media(media)

    page = socket.assigns.current_page
    {items, total_count} = Content.list_media_paginated(page, @per_page, socket.assigns.search, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
     |> stream_delete(:media_collection, media)
     |> stream(:media_collection, items, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {items, total_count} = Content.list_media_paginated(1, @per_page, term, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, term)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
     |> stream(:media_collection, items, reset: true)
     |> push_patch(to: patch_path("/admin/media", 1, socket.assigns.sort_by, socket.assigns.sort_dir))}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {items, total_count} = Content.list_media_paginated(1, @per_page, "", sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
     |> stream(:media_collection, items, reset: true)
     |> push_patch(to: patch_path("/admin/media", 1, socket.assigns.sort_by, socket.assigns.sort_dir))}
  end

  defp patch_path(base, page, sort_by, sort_dir) do
    "#{base}?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
  end
end