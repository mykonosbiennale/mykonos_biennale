defmodule MykonosBiennaleWeb.Admin.SectionLive.Show do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Site
  alias MykonosBiennale.Site.Section

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:active_tab, "default")}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    section = Site.get_section!(id)
    page_title = (section.page && section.page.title) || "Unknown Page"

    {:noreply,
     socket
     |> assign(:page_title, section.title || "Section ##{section.id}")
     |> assign(:section, section)
     |> assign(:page_title_value, page_title)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("change", %{"content" => content}, socket) do
    case Jason.decode(content) do
      {:ok, new_metadata} ->
        section = socket.assigns.section

        {:ok, section} =
          section
          |> Section.changeset(%{metadata: new_metadata})
          |> MykonosBiennale.Repo.update()

        {:noreply, assign(socket, :section, section)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.SectionLive.FormComponent, {:saved, section}}, socket) do
    {:noreply, assign(socket, :section, section)}
  end

  @impl true
  def handle_info({:metadata_changed, %{content: content}}, socket) do
    case Jason.decode(content) do
      {:ok, new_metadata} ->
        section = socket.assigns.section

        section
        |> Section.changeset(%{metadata: new_metadata})
        |> MykonosBiennale.Repo.update!()

        {:noreply, assign(socket, :section, %{section | metadata: new_metadata})}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
