defmodule MykonosBiennaleWeb.Admin.PageLive.Show do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Site
  alias MykonosBiennale.Site.Page

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:active_tab, "default")}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    page = Site.get_page!(id)

    {:noreply,
     socket
     |> assign(:page_title, page.title || "Page ##{page.id}")
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("change", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, new_metadata} ->
        page = socket.assigns.page

        {:ok, page} =
          page
          |> Page.changeset(%{metadata: new_metadata})
          |> MykonosBiennale.Repo.update()

        {:noreply, assign(socket, :page, page)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.PageLive.FormComponent, {:saved, page}}, socket) do
    {:noreply, assign(socket, :page, page)}
  end

  @impl true
  def handle_info({:metadata_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_metadata} ->
        page = socket.assigns.page

        page
        |> Page.changeset(%{metadata: new_metadata})
        |> MykonosBiennale.Repo.update!()

        {:noreply, assign(socket, :page, %{page | metadata: new_metadata})}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
