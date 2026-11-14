defmodule MykonosBiennaleWeb.DiscoveryTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /sitemap.xml" do
    test "serves XML listing visible editions", %{conn: conn} do
      shown = ContentFixtures.biennale_fixture(year: 2031)

      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      assert ["application/xml; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert body =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert body =~ "/biennale/#{shown.slug}"
      assert body =~ "<loc>"
    end

    test "leaves out hidden editions", %{conn: conn} do
      hidden = ContentFixtures.biennale_fixture(year: 2032, visible: false)

      body = response(get(conn, ~p"/sitemap.xml"), 200)

      refute body =~ "/biennale/#{hidden.slug}"
    end
  end

  describe "GET /llms.txt" do
    test "serves a markdown summary with the site and its editions", %{conn: conn} do
      shown = ContentFixtures.biennale_fixture(year: 2033)

      conn = get(conn, ~p"/llms.txt")
      body = response(conn, 200)

      assert ["text/plain; charset=utf-8"] = get_resp_header(conn, "content-type")
      assert String.starts_with?(body, "# Mykonos Biennale")
      assert body =~ "## Editions"
      assert body =~ "[Mykonos Biennale 2033](http://"
      assert body =~ "/biennale/#{shown.slug}"
    end

    test "leaves out hidden editions", %{conn: conn} do
      hidden = ContentFixtures.biennale_fixture(year: 2034, visible: false)

      body = response(get(conn, ~p"/llms.txt"), 200)

      refute body =~ "/biennale/#{hidden.slug}"
    end
  end
end
