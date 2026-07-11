defmodule MykonosBiennaleWeb.AuthMatrixTest do
  use MykonosBiennaleWeb.ConnCase

  @moduledoc """
  Table-driven test that hits every admin route anonymously and asserts
  redirect to the login page. Also tests that a non-admin authenticated
  user is rejected from admin routes.
  """

  @admin_routes [
    "/admin",
    "/admin/biennales",
    "/admin/biennales/new",
    "/admin/biennales/1/edit",
    "/admin/biennales/1",
    "/admin/events",
    "/admin/events/new",
    "/admin/events/1",
    "/admin/events/1/edit",
    "/admin/participants",
    "/admin/participants/new",
    "/admin/participants/1/edit",
    "/admin/participants/1/artworks/new",
    "/admin/participants/1",
    "/admin/films",
    "/admin/films/new",
    "/admin/films/1/edit",
    "/admin/films/1",
    "/admin/artworks",
    "/admin/artworks/import_preview",
    "/admin/artworks/merge",
    "/admin/artworks/new",
    "/admin/artworks/1/edit",
    "/admin/artworks/1",
    "/admin/projects",
    "/admin/projects/new",
    "/admin/projects/1",
    "/admin/projects/1/edit",
    "/admin/media",
    "/admin/media/new",
    "/admin/media/rotate",
    "/admin/media/1",
    "/admin/media/1/edit",
    "/admin/pages",
    "/admin/pages/new",
    "/admin/pages/1",
    "/admin/pages/1/edit",
    "/admin/sections",
    "/admin/sections/new",
    "/admin/sections/1",
    "/admin/sections/1/edit",
    "/admin/relationship_types",
    "/admin/relationship_types/new",
    "/admin/relationship_types/1/edit",
    "/admin/relationships",
    "/admin/relationships/new",
    "/admin/relationships/1",
    "/admin/relationships/1/edit",
    "/admin/users",
    "/admin/users/new",
    "/admin/users/1/edit"
  ]

  describe "anonymous user" do
    for path <- @admin_routes do
      @tag :auth_matrix
      test "GET #{path} redirects to login" do
        conn = Phoenix.ConnTest.build_conn()
        conn = get(conn, unquote(path))
        assert conn.status == 302
        [location] = get_resp_header(conn, "location")
        assert String.contains?(location, "/users/log-in")
      end
    end
  end

  describe "authenticated non-admin user" do
    for path <- @admin_routes do
      @tag :auth_matrix
      test "GET #{path} redirects non-admin user" do
        user = MykonosBiennale.AccountsFixtures.user_fixture()
        token = MykonosBiennale.Accounts.generate_user_session_token(user)

        conn =
          Phoenix.ConnTest.build_conn()
          |> Phoenix.ConnTest.init_test_session(%{})
          |> Plug.Conn.put_session(:user_token, token)

        conn = get(conn, unquote(path))
        assert conn.status == 302
      end
    end
  end
end
