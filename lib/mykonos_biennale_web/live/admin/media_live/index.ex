defmodule MykonosBiennaleWeb.Admin.MediaLive.Index do
  use MykonosBiennaleWeb, :live_view

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search, "")
     |> stream(:media_collection, list_media_filtered(""))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit Media") |> assign(:media, Content.get_media!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New Media") |> assign(:media, %Media{})
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Media Library") |> assign(:media, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.MediaLive.FormComponent, {:saved, media}}, socket) do
    {:noreply, stream_insert(socket, :media_collection, media)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    media = Content.get_media!(id)
    {:ok, _} = Content.delete_media(media)
    {:noreply, stream_delete(socket, :media_collection, media)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    {:noreply, socket |> assign(:search, term) |> stream(:media_collection, list_media_filtered(term), reset: true)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> stream(:media_collection, list_media_filtered(""), reset: true)}
  end

  defp list_media_filtered(""), do: Content.list_media()
  defp list_media_filtered(term) do
    pattern = Search.entity_search_pattern(term)

    Repo.all(
      from m in Media,
        where: not is_nil(m.search_index) and like(m.search_index, ^pattern),
        order_by: [desc: m.inserted_at]
    )
  end
end
