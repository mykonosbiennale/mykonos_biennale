defmodule MykonosBiennaleWeb.Admin.EventLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Relationship

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Events")
     |> stream(:events, Content.list_events_for_admin())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Event")
    |> assign(:event, Content.get_event_for_admin!(id))
  end

  defp apply_action(socket, :new, _params) do
    # Create a new entity with type "event" instead of %Event{}
    socket
    |> assign(:page_title, "New Event")
    |> assign(:event, %Content.Entity{type: "event", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Events")
    |> assign(:event, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.EventLive.FormComponent, {:saved, event}},
        socket
      ) do
    # Ensure the streamed row has the biennale relationship preloaded for rendering.
    event = Content.get_event_for_admin!(event.id)
    {:noreply, stream_insert(socket, :events, event)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Content.get_event!(id)
    {:ok, _} = Content.delete_event(event)

    {:noreply, stream_delete(socket, :events, event)}
  end

  # Template helpers (admin events are `Content.Entity` records with domain fields under `fields`)
  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default

  defp event_festival(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &match?(%Relationship{slug: "event_festival"}, &1)) do
      %Relationship{object: %Content.Entity{} = festival} -> festival
      _ -> nil
    end
  end

  defp event_festival(%Content.Entity{}), do: nil

  defp event_project(%Content.Entity{as_subject: rels}) when is_list(rels) do
    case Enum.find(rels, &match?(%Relationship{slug: "event_project"}, &1)) do
      %Relationship{object: %Content.Entity{} = project} -> project
      _ -> nil
    end
  end

  defp event_project(%Content.Entity{}), do: nil

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
