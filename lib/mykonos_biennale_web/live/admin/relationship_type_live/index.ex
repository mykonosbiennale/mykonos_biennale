defmodule MykonosBiennaleWeb.Admin.RelationshipTypeLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Relationship Types")
     |> stream(:relationship_types, Content.list_relationship_types())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Relationship Type")
    |> assign(:relationship_type, Content.get_relationship_type!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Relationship Type")
    |> assign(:relationship_type, %Content.RelationshipType{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Relationship Types")
    |> assign(:relationship_type, nil)
  end

  @impl true
  def handle_info(
        {MykonosBiennaleWeb.Admin.RelationshipTypeLive.FormComponent,
         {:saved, relationship_type}},
        socket
      ) do
    {:noreply, stream_insert(socket, :relationship_types, relationship_type)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    relationship_type = Content.get_relationship_type!(id)
    {:ok, _} = Content.delete_relationship_type(relationship_type)

    {:noreply, stream_delete(socket, :relationship_types, relationship_type)}
  end
end
