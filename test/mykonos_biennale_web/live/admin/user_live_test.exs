defmodule MykonosBiennaleWeb.Admin.UserLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists users", %{conn: conn, admin: admin} do
      {:ok, _lv, html} = live(conn, ~p"/admin/users")
      assert html =~ "Users"
      assert html =~ admin.email
    end

    test "has + New User link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/users")
      assert html =~ "/admin/users/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")
      html = lv |> element("#user-form") |> render()
      assert html =~ "email"
    end

    test "creates user on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/new")

      lv
      |> form("#user-form",
        user: %{email: "newuser-#{System.unique_integer()}@example.com", role: "staff"}
      )
      |> render_submit()

      assert_patch(lv, ~p"/admin/users")
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn, admin: admin} do
      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{admin.id}/edit")
      html = lv |> element("#user-form") |> render()
      assert html =~ admin.email
    end
  end

  describe "Delete" do
    test "deletes user from index", %{conn: conn} do
      user = MykonosBiennale.AccountsFixtures.user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/admin/users")
      lv |> element("[phx-click=delete][phx-value-id='#{user.id}']") |> render_click()
    end
  end

  describe "Auth — non-admin rejected" do
    test "non-admin authenticated user is redirected from /admin/users" do
      user = MykonosBiennale.AccountsFixtures.user_fixture()
      token = MykonosBiennale.Accounts.generate_user_session_token(user)

      conn =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      conn = get(conn, ~p"/admin/users")
      assert conn.status == 302
    end
  end
end
