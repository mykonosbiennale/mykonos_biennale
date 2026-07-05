defmodule MykonosBiennaleWeb.Admin.EventLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @per_page 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Events")
     |> assign(:search, "")
     |> assign(:current_page, 1)
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
      |> assign(:sort_by, :id)
      |> assign(:sort_dir, :desc)
     |> stream(:events, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = String.to_integer(params["page"] || "1")
    search = socket.assigns.search
    sort_by = (params["sort_by"] || "id") |> String.to_atom()
    sort_dir = (params["sort_dir"] || "desc") |> String.to_atom()

    {events, total_count} =
      Content.list_events_paginated(page, @per_page, search, sort_by: sort_by, sort_dir: sort_dir)

    total_pages = max(1, ceil(total_count / @per_page))

    return_path =
      if socket.assigns.live_action == :index do
        "/admin/events?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
      else
        socket.assigns[:return_path] || "/admin/events"
      end

    socket =
      socket
      |> assign(:current_page, page)
      |> assign(:total_pages, total_pages)
      |> assign(:total_count, total_count)
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:return_path, return_path)
      |> stream(:events, events, reset: true)

    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Event")
    |> assign(:event, Content.get_event_for_admin!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Event")
    |> assign(:event, Content.get_event_for_admin!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Event")
    |> assign(:event, %Content.Entity{type: "event", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Events") |> assign(:event, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.EventLive.FormComponent, {:saved, _event}}, socket) do
    page = socket.assigns.current_page

    {events, total_count} =
      Content.list_events_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Content.get_event!(id)
    {:ok, _} = Content.delete_event(event)

    page = socket.assigns.current_page

    {events, total_count} =
      Content.list_events_paginated(page, @per_page, socket.assigns.search,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir
      )

    total_pages = max(1, ceil(total_count / @per_page))

    {:noreply,
     socket
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, total_count)
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {events, total_count} =
      Content.list_events_paginated(1, @per_page, term,
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
     |> stream(:events, events, reset: true)
     |> push_patch(
       to: patch_path("/admin/events", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {events, total_count} =
      Content.list_events_paginated(1, @per_page, "",
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
     |> stream(:events, events, reset: true)
     |> push_patch(
       to: patch_path("/admin/events", 1, socket.assigns.sort_by, socket.assigns.sort_dir)
     )}
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp patch_path(base, page, sort_by, sort_dir) do
    "#{base}?#{URI.encode_query(%{page: page, sort_by: sort_by, sort_dir: sort_dir})}"
  end

  defp field(%Content.Entity{}, _key, default), do: default

  defp event_biennale(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &rel_type_slug?(&1, "biennale_event")) do
      %Content.Relationship{object: %Content.Entity{} = biennale} -> biennale
      _ -> nil
    end
  end

  defp event_biennale(%Content.Entity{}), do: nil

  defp event_project(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &rel_type_slug?(&1, "event_project")) do
      %Content.Relationship{object: %Content.Entity{} = project} -> project
      _ -> nil
    end
  end

  defp event_project(%Content.Entity{}), do: nil

  defp rel_type_slug?(
         %Content.Relationship{relationship_type: %Content.RelationshipType{slug: slug}},
         slug
       ),
       do: true

  defp rel_type_slug?(_, _), do: false

  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(nil), do: :error

  defp parse_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> {:ok, d}
      _ -> :error
    end
  end

  defp parse_date(_), do: :error

  defp format_event_date(%Content.Entity{} = event) do
    case parse_date(field(event, "date")) do
      {:ok, d} -> Calendar.strftime(d, "%b %d, %Y")
      :error -> nil
    end
  end
end
