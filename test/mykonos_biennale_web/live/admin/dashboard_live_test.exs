defmodule MykonosBiennaleWeb.Admin.DashboardLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Dashboard" do
    test "renders dashboard with recent changes", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "Recent Changes"
    end

    test "shows quick action links", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin")
      assert html =~ "/admin/events/new"
      assert html =~ "/admin/participants/new"
      assert html =~ "/admin/artworks/new"
      assert html =~ "/admin/films/new"
    end
  end

  describe "Auth" do
    test "anonymous user redirected from /admin", %{conn: _conn} do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, ~p"/admin")
      assert conn.status == 302
    end
  end
end
