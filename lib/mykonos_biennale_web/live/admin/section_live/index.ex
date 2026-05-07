defmodule MykonosBiennaleWeb.Admin.SectionLive.Index do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Site

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :sections, Site.list_sections())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Section")
    |> assign(:section, Site.get_section!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Section")
    |> assign(:section, %Site.Section{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Sections")
    |> assign(:section, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.SectionLive.FormComponent, {:saved, section}}, socket) do
    {:noreply, stream_insert(socket, :sections, section)}
  end

  @impl true
  def handle_event("change", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, metadata} ->
        send_update(MykonosBiennaleWeb.Admin.SectionLive.FormComponent,
          id: socket.assigns.section.id || :new,
          metadata: metadata
        )

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    section = Site.get_section!(id)
    {:ok, _} = Site.delete_section(section)

    {:noreply,
     socket
     |> put_flash(:info, "Section deleted successfully")
     |> stream_delete(:sections, section)}
  end
end
