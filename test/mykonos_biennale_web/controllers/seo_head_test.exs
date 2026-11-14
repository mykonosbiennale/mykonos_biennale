defmodule MykonosBiennaleWeb.SEOHeadTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest

  alias MykonosBiennale.ContentFixtures

  describe "festival edition page" do
    test "renders description, canonical link, Open Graph and an Event JSON-LD block", %{
      conn: conn
    } do
      biennale =
        ContentFixtures.biennale_fixture(
          year: 2025,
          statement: "<p>A statement about 2025</p>",
          start_date: "2025-09-27",
          end_date: "2025-10-05"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)

      assert html =~ ~s(<link rel="canonical")
      assert html =~ ~s(name="description" content="A statement about 2025")
      assert html =~ ~s(property="og:title")
      assert html =~ ~s(property="og:image")
      assert html =~ "/images/og-default.png"
      assert html =~ ~s(name="twitter:card" content="summary_large_image")
      assert html =~ ~s(type="application/ld+json")
      assert html =~ ~s("@type":"Event")
      assert html =~ ~s("startDate":"2025-09-27")
    end
  end

  describe "home page" do
    test "uses the default Open Graph and Twitter image", %{conn: conn} do
      html = html_response(get(conn, "/"), 200)

      assert html =~ "/images/og-default.png"
      assert html =~ ~s(name="twitter:image")
    end
  end

  describe "search page" do
    test "is marked noindex", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/search")

      assert html =~ ~s(name="robots" content="noindex, nofollow")
    end
  end
end
