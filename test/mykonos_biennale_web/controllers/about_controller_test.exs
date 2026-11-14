defmodule MykonosBiennaleWeb.AboutControllerTest do
  use MykonosBiennaleWeb.ConnCase

  test "renders the about page as a regular page", %{conn: conn} do
    html = html_response(get(conn, ~p"/about"), 200)

    assert html =~ "The Mykonos Biennale"
    assert html =~ "Our Programs"
    assert html =~ "Exhibitions"
    assert html =~ "Performances"
    assert html =~ "Short Films"
  end

  test "renders the location and visit sections", %{conn: conn} do
    html = html_response(get(conn, ~p"/about"), 200)

    assert html =~ "Mykonos, Greece"
    assert html =~ "View Current Program"
  end

  test "has a canonical link and no noindex", %{conn: conn} do
    html = html_response(get(conn, ~p"/about"), 200)

    assert html =~ ~s(rel="canonical")
    refute html =~ "noindex"
  end
end
