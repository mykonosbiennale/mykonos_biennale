defmodule MykonosBiennaleWeb.UserLive.RegistrationTest do
  use MykonosBiennaleWeb.ConnCase, async: true

  # Public registration is disabled in this app — no /users/register route exists.
  # These tests are kept for reference but skipped.
  import Phoenix.LiveViewTest
  import MykonosBiennale.AccountsFixtures
  alias MykonosBiennale.Accounts

  @register_path "/users/register"

  describe "Registration page (disabled)" do
    @tag :skip
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, @register_path)

      assert html =~ "Register"
      assert html =~ "Log in"
    end

    @tag :skip
    test "redirects if already logged in", %{conn: conn} do
      user = user_fixture()
      conn = conn |> log_in_user(user) |> live(@register_path)
      assert_redirect(conn, ~p"/")
    end
  end

  describe "register user (disabled)" do
    @tag :skip
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @register_path)

      email = unique_user_email()

      lv
      |> form("#registration_form", user: valid_user_attributes(email: email))
      |> render_submit()

      conn = follow_trigger_action(lv, conn)

      assert redirected_to(conn) == ~p"/users/log-in"

      user = Accounts.get_user_by_email(email)
      refute user.confirmed_at
    end

    @tag :skip
    test "renders errors for duplicated email", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, @register_path)

      lv
      |> form("#registration_form", user: valid_user_attributes(email: user.email))
      |> render_change()

      assert lv |> element("#registration_form") |> render() =~ "has already been taken"
    end

    @tag :skip
    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @register_path)

      lv
      |> form("#registration_form", user: %{email: "not an email", password: "123"})
      |> render_change()

      assert lv |> element("#registration_form") |> render() =~ "must be a valid email"
    end
  end

  describe "registration navigation (disabled)" do
    @tag :skip
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, @register_path)

      {:ok, _registration_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
