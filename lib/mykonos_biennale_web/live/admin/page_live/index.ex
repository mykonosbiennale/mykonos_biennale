defmodule MykonosBiennaleWeb.Admin.PageLive.Index do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Site

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :pages, Site.list_pages())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Page")
    |> assign(:page, Site.get_page!(id))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Page")
    |> assign(:page, Site.get_page!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Page")
    |> assign(:page, %Site.Page{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Pages")
    |> assign(:page, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.PageLive.FormComponent, {:saved, page}}, socket) do
    {:noreply, stream_insert(socket, :pages, page)}
  end

  @impl true
  def handle_event("change", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, metadata} ->
        send_update(MykonosBiennaleWeb.Admin.PageLive.FormComponent,
          id: socket.assigns.page.id || :new,
          metadata: metadata
        )

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    page = Site.get_page!(id)
    {:ok, _} = Site.delete_page(page)

    {:noreply,
     socket
     |> put_flash(:info, "Page deleted successfully")
     |> stream_delete(:pages, page)}
  end
end
