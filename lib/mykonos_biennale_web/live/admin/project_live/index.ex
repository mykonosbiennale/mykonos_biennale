defmodule MykonosBiennaleWeb.Admin.ProjectLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Projects")
     |> stream(:projects, Content.list_projects())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Project")
    |> assign(:project, Content.get_project!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "Show Project")
    |> assign(:project, Content.get_project!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Project")
    |> assign(:project, %Content.Entity{type: "project", fields: %{}})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Manage Projects")
    |> assign(:project, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.ProjectLive.FormComponent, {:saved, project}},
        socket
      ) do
    {:noreply, stream_insert(socket, :projects, project)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    project = Content.get_project!(id)
    {:ok, _} = Content.delete_project(project)

    {:noreply, stream_delete(socket, :projects, project)}
  end

  defp field(entity, key, default \\ nil)

  defp field(%Content.Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(%Content.Entity{}, _key, default), do: default
end
