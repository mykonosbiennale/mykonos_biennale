defmodule MykonosBiennaleWeb.Admin.ParticipantLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Participants")
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:sort_by, :name)
     |> assign(:sort_dir, :asc)
     |> stream(:participants, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "name") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "asc") |> String.to_atom()

    {participants, total_count} =
      Content.list_participants_paginated(page, @per_page, search,
        sort_by: sort_by,
        sort_dir: sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> stream(:participants, participants, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Participant")
    |> assign(:participant, Content.get_participant!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Participant")
    |> assign(:participant, Content.get_participant!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Participant")
    |> assign(:participant, %Content.Entity{type: "participant", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Participants") |> assign(:participant, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ParticipantLive.FormComponent, {:saved, _participant}},
        socket
      ) do
    page = socket.assigns.current_page

    {participants, total_count} =
      Content.list_participants_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:participants, participants, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    participant = Content.get_participant!(id)
    {:ok, _} = Content.delete_participant(participant)

    page = socket.assigns.current_page

    {participants, total_count} =
      Content.list_participants_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:participants, participants, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {participants, total_count} =
      Content.list_participants_paginated(1, @per_page, term,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, term)
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:participants, participants, reset: true)
     |> push_patch(
       to: patch_path("/admin/participants", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {participants, total_count} =
      Content.list_participants_paginated(1, @per_page, "",
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:participants, participants, reset: true)
     |> push_patch(
       to: patch_path("/admin/participants", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
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
