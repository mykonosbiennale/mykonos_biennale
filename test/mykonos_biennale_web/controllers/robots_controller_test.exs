defmodule MykonosBiennaleWeb.RobotsControllerTest do
  use MykonosBiennaleWeb.ConnCase

  test "serves robots.txt that allows crawling and points to the sitemap", %{conn: conn} do
    conn = get(conn, ~p"/robots.txt")
    body = response(conn, 200)

    assert ["text/plain; charset=utf-8"] = get_resp_header(conn, "content-type")
    assert body =~ "User-agent: *"
    assert body =~ "Allow: /"
    assert body =~ "Sitemap: http"
    assert body =~ "/sitemap.xml"
  end
end
