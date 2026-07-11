defmodule MykonosBiennaleWeb.PageControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  test "GET / renders home page with active biennale", %{conn: conn} do
    _biennale =
      ContentFixtures.biennale_fixture(
        year: 2025,
        theme: "Test Biennale Theme",
        template: "default",
        start_date: "2025-09-27",
        end_date: "2025-10-05"
      )

    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Test Biennale Theme"
    assert html =~ "2025"
  end

  test "GET / renders without biennale data (fallback)", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Mykonos Biennale"
  end
end
