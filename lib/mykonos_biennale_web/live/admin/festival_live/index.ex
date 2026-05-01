defmodule MykonosBiennaleWeb.Admin.FestivalLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Festivals")
     |> stream(:festivals, Content.list_festivals())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Festival")
    |> assign(:festival, Content.get_festival!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Festival")
    |> assign(:festival, Content.get_festival!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Festival")
    |> assign(:festival, %Content.Entity{type: "festival", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Festivals")
    |> assign(:festival, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.FestivalLive.FormComponent, {:saved, festival}},
        socket
      ) do
    {:noreply, stream_insert(socket, :festivals, festival)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    festival = Content.get_festival!(id)
    {:ok, _} = Content.delete_festival(festival)

    {:noreply, stream_delete(socket, :festivals, festival)}
  end

  # Template helpers
  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
