defmodule MykonosBiennaleWeb.Admin.RelationshipLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    relationship_types = Content.list_relationship_types()

    {:ok,
     socket
     |> assign(:page_title, "Relationships")
     |> assign(:relationship_types, relationship_types)
     |> assign(:relationship, nil)
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:sort_by, :inserted_at)
     |> assign(:sort_dir, :desc)
     |> stream(:relationships, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "inserted_at") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "desc") |> String.to_atom()

    {relationships, total_count} = Content.list_relationships_paginated(page, @per_page, search, sort_by: sort_by, sort_dir: sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> stream(:relationships, relationships, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    rel = Content.get_relationship!(id)
    socket |> assign(:page_title, "Edit Relationship") |> assign(:relationship, rel)
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Relationship") |> assign(:relationship, %Content.Relationship{})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Relationships") |> assign(:relationship, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.RelationshipLive.FormComponent, {:saved, _rel}},
        socket
      ) do
    page = socket.assigns.current_page
    {relationships, total_count} = Content.list_relationships_paginated(page, @per_page, socket.assigns.search, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:relationships, relationships, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    rel = Content.get_relationship!(id)
    {:ok, _} = Content.delete_relationship(rel)

    page = socket.assigns.current_page
    {relationships, total_count} = Content.list_relationships_paginated(page, @per_page, socket.assigns.search, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:relationships, relationships, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {relationships, total_count} = Content.list_relationships_paginated(1, @per_page, term, sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, term)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:relationships, relationships, reset: true)
     |> push_patch(to: path_url("/admin/relationships", 1, socket.assigns.sort_by, socket.assigns.sort_dir))}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {relationships, total_count} = Content.list_relationships_paginated(1, @per_page, "", sort_by: socket.assigns.sort_by, sort_dir: socket.assigns.sort_dir)
    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:relationships, relationships, reset: true)
     |> push_patch(to: path_url("/admin/relationships", 1, socket.assigns.sort_by, socket.assigns.sort_dir))}
  end

  defp path_url(base, page, sort_by, sort_dir) do
    "#{base}?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
  end

  defp entity_label(%Content.Entity{identity: identity}) when is_binary(identity) and identity != "",
    do: identity

  defp entity_label(%Content.Entity{fields: fields}) when is_map(fields) do
    Map.get(fields, "name") ||
      "#{Map.get(fields, "first_name", "")} #{Map.get(fields, "last_name", "")}"
      |> String.trim()
  end

  defp entity_label(%Content.Entity{id: id}), do: "##{id}"

  defp entity_type_badge(%Content.Entity{type: type}), do: type

  defp entity_path(%Content.Entity{type: "participant"} = e), do: "/admin/participants/#{e.id}"
  defp entity_path(%Content.Entity{type: "artwork"} = e), do: "/admin/artworks/#{e.id}"
  defp entity_path(%Content.Entity{type: "event"} = e), do: "/admin/events/#{e.id}"
  defp entity_path(%Content.Entity{type: "biennale"} = e), do: "/admin/biennales/#{e.id}"
  defp entity_path(%Content.Entity{type: "project"} = e), do: "/admin/projects/#{e.id}"
  defp entity_path(%Content.Entity{type: "festival"} = e), do: "/admin/festivals/#{e.id}"
  defp entity_path(%Content.Entity{} = e) do
    film_types = ["Short Film", "Video", "Dance", "Animation", "Documentary"]
    if e.type in film_types, do: "/admin/films/#{e.id}", else: "#"
  end

  defp format_fields(nil), do: ""
  defp format_fields(fields) when is_map(fields) do
    fields |> Enum.map(fn {k, v} -> "#{k}: #{v}" end) |> Enum.join(", ")
  end
end