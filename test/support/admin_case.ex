defmodule MykonosBiennaleWeb.AdminCase do
  @moduledoc """
  Test case for admin LiveView tests.
  Logs in a user with the "admin" role and provides Content fixtures.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use MykonosBiennaleWeb, :verified_routes

      @endpoint MykonosBiennaleWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import MykonosBiennaleWeb.AdminCase

      alias MykonosBiennale.Repo
      alias MykonosBiennale.Content
      alias MykonosBiennale.ContentFixtures
      alias MykonosBiennale.SiteFixtures
    end
  end

  setup tags do
    MykonosBiennale.DataCase.setup_sandbox(tags)

    admin = admin_user_fixture()
    conn = Phoenix.ConnTest.build_conn() |> log_in_admin(admin)

    {:ok, conn: conn, admin: admin}
  end

  @doc "Creates a user with admin role and logs them in."
  def log_in_admin(conn, user) do
    token = MykonosBiennale.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  @doc "Creates an admin-role user."
  def admin_user_fixture(attrs \\ %{}) do
    user = MykonosBiennale.AccountsFixtures.user_fixture()

    user
    |> Ecto.Changeset.change(role: :admin)
    |> MykonosBiennale.Repo.update!()
  end
end
