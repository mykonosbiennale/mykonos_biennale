defmodule MykonosBiennaleWeb.Admin.UserLive.FormComponent do
  use MykonosBiennaleWeb, :live_component

  alias MykonosBiennale.Accounts
  alias MykonosBiennale.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl [&_.label]:text-gray-900 [&_h1]:text-gray-900">
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="user-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
        novalidate
      >
        <div class="space-y-4">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input
            field={@form[:role]}
            type="select"
            label="Role"
            options={[{"Admin", "admin"}, {"Staff", "staff"}, {"Participant", "participant"}]}
            prompt="Choose role"
          />
          <%= if @action == :new do %>
            <.input field={@form[:password]} type="password" label="Password" required />
            <.input field={@form[:password_confirmation]} type="password" label="Confirm password" />
          <% end %>
        </div>

        <div class="mt-6 flex items-center justify-end gap-x-6">
          <.link patch={@patch} class="text-sm font-semibold text-gray-500 hover:text-gray-700">
            Cancel
          </.link>
          <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save User
          </button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{user: user, action: action} = assigns, socket) do
    changeset =
      case action do
        :new -> User.admin_changeset(%User{}, %{})
        :edit -> User.admin_changeset(user, %{})
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form, to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> User.admin_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :user))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :user))}
    end
  end

  defp save_user(socket, :new, user_params) do
    Accounts.register_user(user_params)
    |> case do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :user))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end