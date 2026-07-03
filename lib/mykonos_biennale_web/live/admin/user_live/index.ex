defmodule MykonosBiennaleWeb.Admin.UserLive.Index do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Manage Users")
     |> stream(:users, Accounts.list_users())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket |> assign(:page_title, "New User") |> assign(:user, %Accounts.User{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket |> assign(:page_title, "Edit User") |> assign(:user, Accounts.get_user!(id))
  end

  defp apply_action(socket, :index, _params) do
    socket |> assign(:page_title, "Manage Users") |> assign(:user, nil)
  end

  @impl true
  def handle_info({MykonosBiennaleWeb.Admin.UserLive.FormComponent, {:saved, user}}, socket) do
    {:noreply, stream_insert(socket, :users, user)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)
    {:noreply, stream_delete(socket, :users, user)}
  end

  @impl true
  def handle_event("send_magic_link", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    Accounts.deliver_login_instructions(user, fn token ->
      MykonosBiennaleWeb.Endpoint.url() <> "/users/log-in/#{token}"
    end)

    {:noreply, put_flash(socket, :info, "Magic link sent to #{user.email}")}
  end
end
