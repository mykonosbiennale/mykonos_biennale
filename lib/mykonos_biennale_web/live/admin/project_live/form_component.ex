defmodule MykonosBiennaleWeb.Admin.ProjectLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Content
  alias Ecto.Changeset

  defmodule ProjectForm do
    @moduledoc false
    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :title, :string
      field :description, :string
      field :statement, :string
      field :visible, :boolean, default: true
    end

    def changeset(%__MODULE__{} = form, attrs) when is_map(attrs) do
      form
      |> cast(attrs, [:title, :description, :statement, :visible])
      |> validate_required([:title])
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="project-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="textarea" label="Description" rows="4" />
          <.input field={@form[:statement]} type="textarea" label="Statement" rows="4" />
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Project
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{project: project} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       changeset = ProjectForm.changeset(%ProjectForm{}, project_form_attrs(project))
       to_form(changeset, as: :project)
     end)}
  end

  @impl true
  def handle_event("validate", params, socket) do
    project_params = extract_project_params(params)

    changeset =
      socket.assigns.form.source.data
      |> ProjectForm.changeset(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :project))}
  end

  def handle_event("save", params, socket) do
    project_params = extract_project_params(params)
    save_project(socket, socket.assigns.action, project_params)
  end

  defp save_project(socket, :edit, project_params) do
    changeset = ProjectForm.changeset(socket.assigns.form.source.data, project_params)

    if changeset.valid? do
      attrs = project_attrs_from_form(changeset)

      case Content.update_project(socket.assigns.project, attrs) do
        {:ok, project} ->
          notify_parent({:saved, project})

          {:noreply,
           socket
           |> put_flash(:info, "Project updated successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not update project")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :project)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :project))}
    end
  end

  defp save_project(socket, :new, project_params) do
    changeset = ProjectForm.changeset(socket.assigns.form.source.data, project_params)

    if changeset.valid? do
      attrs = project_attrs_from_form(changeset)

      case Content.create_project(attrs) do
        {:ok, project} ->
          notify_parent({:saved, project})

          {:noreply,
           socket
           |> put_flash(:info, "Project created successfully")
           |> push_patch(to: socket.assigns.patch)}

        {:error, %Ecto.Changeset{}} ->
          {:noreply,
           socket
           |> put_flash(:error, "Could not create project")
           |> assign(
             :form,
             to_form(Changeset.add_error(changeset, :base, "Save failed"), as: :project)
           )}
      end
    else
      {:noreply, assign(socket, form: to_form(%{changeset | action: :validate}, as: :project))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp extract_project_params(%{"project" => p}) when is_map(p), do: p
  defp extract_project_params(_), do: %{}

  defp project_form_attrs(%Content.Entity{fields: fields}) when is_map(fields) do
    %{
      title: Map.get(fields, "title"),
      description: Map.get(fields, "description"),
      statement: Map.get(fields, "statement"),
      visible: true
    }
  end

  defp project_form_attrs(%Content.Entity{}), do: %{visible: true}

  defp project_attrs_from_form(%Changeset{} = changeset) do
    form = Changeset.apply_changes(changeset)

    %{
      title: form.title,
      description: form.description,
      statement: form.statement
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
