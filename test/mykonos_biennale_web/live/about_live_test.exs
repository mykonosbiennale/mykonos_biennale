defmodule MykonosBiennaleWeb.AboutLiveTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest

  test "mounts /about and renders about page", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/about")
    assert html =~ "About"
    assert html =~ "The Mykonos Biennale"
    assert html =~ "Our Programs"
    assert html =~ "Exhibitions"
    assert html =~ "Performances"
    assert html =~ "Short Films"
  end

  test "renders location section", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/about")
    assert html =~ "Location"
    assert html =~ "Mykonos, Greece"
  end

  test "renders visit section with program link", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/about")
    assert html =~ "Visit"
    assert html =~ "View Current Program"
  end
end
