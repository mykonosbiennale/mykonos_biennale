defmodule MykonosBiennaleWeb.Admin.RelationshipTypeLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias Ecto.Changeset

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="relationship-type-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:label]} type="text" label="Label" required />
          <.input field={@form[:slug]} type="text" label="Slug" required />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Relationship Type
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{relationship_type: relationship_type} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       changeset = Content.RelationshipType.changeset(relationship_type, %{})
       to_form(changeset, as: :relationship_type)
     end)}
  end

  @impl true
  def handle_event("validate", %{"relationship_type" => rt_params}, socket) do
    changeset =
      socket.assigns.relationship_type
      |> Content.RelationshipType.changeset(rt_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :relationship_type))}
  end

  def handle_event("save", %{"relationship_type" => rt_params}, socket) do
    save_relationship_type(socket, socket.assigns.action, rt_params)
  end

  defp save_relationship_type(socket, :edit, rt_params) do
    case Content.update_relationship_type(socket.assigns.relationship_type, rt_params) do
      {:ok, relationship_type} ->
        notify_parent({:saved, relationship_type})

        {:noreply,
         socket
         |> put_flash(:info, "Relationship type updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket, form: to_form(%{changeset | action: :validate}, as: :relationship_type))}
    end
  end

  defp save_relationship_type(socket, :new, rt_params) do
    case Content.create_relationship_type(rt_params) do
      {:ok, relationship_type} ->
        notify_parent({:saved, relationship_type})

        {:noreply,
         socket
         |> put_flash(:info, "Relationship type created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket, form: to_form(%{changeset | action: :validate}, as: :relationship_type))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
