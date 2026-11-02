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

      <%= if @action == :edit do %>
        <div class="mt-6 border-t pt-6">
          <h3 class="text-sm font-semibold text-gray-900 mb-4">Set Temporary Password</h3>
          <%= if @temporary_password do %>
            <div class="mb-4 p-3 bg-green-50 border border-green-200 rounded-md">
              <p class="text-sm text-gray-700 mb-2">Temporary password generated:</p>
              <div class="flex items-center justify-between bg-white p-2 rounded border border-gray-300 mb-3">
                <code id="temp-password" class="text-sm font-mono font-bold text-gray-900">
                  {@temporary_password}
                </code>
                <button
                  type="button"
                  id="copy-password-btn"
                  class="ml-2 text-xs px-2 py-1 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
                  onclick="
                    const password = document.getElementById('temp-password').textContent;
                    navigator.clipboard.writeText(password).then(() => {
                      const btn = document.getElementById('copy-password-btn');
                      const originalText = btn.textContent;
                      btn.textContent = 'Copied!';
                      setTimeout(() => {
                        btn.textContent = originalText;
                      }, 2000);
                    }).catch(err => {
                      console.error('Failed to copy:', err);
                    });
                  "
                >
                  Copy
                </button>
              </div>
              <div class="flex gap-2 mb-2">
                <button
                  type="button"
                  phx-click="send_password_email"
                  phx-target={@myself}
                  class="text-xs px-2 py-1 bg-blue-600 text-white rounded hover:bg-blue-700"
                >
                  Send Password via Email
                </button>
              </div>
              <p class="text-xs text-gray-600">
                You can: (1) copy the password above and send it manually, or (2) click "Send Password via Email" to email it to the user.
              </p>
            </div>
          <% else %>
            <button
              type="button"
              phx-click="generate_password"
              phx-target={@myself}
              class="inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md"
            >
              Generate Temporary Password
            </button>
          <% end %>
        </div>
      <% end %>
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
     |> assign(:form, to_form(changeset, as: :user))
     |> assign(:temporary_password, nil)}
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

  @impl true
  def handle_event("generate_password", _params, socket) do
    user = socket.assigns.user

    case Accounts.set_temporary_password(user) do
      {:ok, _updated_user, password} ->
        {:noreply, assign(socket, :temporary_password, password)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to generate temporary password")}
    end
  end

  @impl true
  def handle_event("copy_password", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_password_email", _params, socket) do
    user = socket.assigns.user
    password = socket.assigns.temporary_password

    case Accounts.send_temporary_password_email(user, password) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password email sent to #{user.email}")
         |> assign(:temporary_password, nil)}

      {:error, _reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Failed to send email. You can copy the password above and send it manually."
         )}
    end
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
