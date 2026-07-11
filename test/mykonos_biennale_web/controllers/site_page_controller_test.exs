defmodule MykonosBiennaleWeb.SitePageControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.SiteFixtures

  describe "GET /page/:slug" do
    test "renders page with title and content", %{conn: conn} do
      page =
        SiteFixtures.page_fixture(
          title: "About Us",
          content: "<p>Welcome to the biennale.</p>",
          slug: "about-us"
        )

      html = html_response(get(conn, "/page/#{page.slug}"), 200)
      assert html =~ "About Us"
      assert html =~ "Welcome to the biennale."
    end

    test "renders page with template none", %{conn: conn} do
      page =
        SiteFixtures.page_fixture(
          title: "Custom Page",
          content: "<p>Custom content.</p>",
          template: "none"
        )

      html = html_response(get(conn, "/page/#{page.slug}"), 200)
      assert html =~ "Custom content."
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/page/nonexistent")
      assert conn.status == 404
    end

    test "404 for invisible page", %{conn: conn} do
      page = SiteFixtures.page_fixture(visible: false)
      conn = get(conn, "/page/#{page.slug}")
      assert conn.status == 404
    end
  end
end
