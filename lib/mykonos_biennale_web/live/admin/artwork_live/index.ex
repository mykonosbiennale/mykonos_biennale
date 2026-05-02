defmodule MykonosBiennaleWeb.Admin.ArtworkLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Artworks")
     |> stream(:artworks, Content.list_artworks())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Artwork")
    |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Artwork")
    |> assign(:artwork, Content.get_artwork!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Artwork")
    |> assign(:artwork, %Content.Entity{type: "artwork", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Artworks")
    |> assign(:artwork, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, artwork}},
        socket
      ) do
    {:noreply, stream_insert(socket, :artworks, artwork)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    artwork = Content.get_artwork!(id)
    {:ok, _} = Content.delete_artwork(artwork)

    {:noreply, stream_delete(socket, :artworks, artwork)}
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
