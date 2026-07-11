defmodule MykonosBiennaleWeb.BiennaleControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /biennale/:slug — default template" do
    test "renders biennale with theme and year", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2024",
          theme: "Test Theme",
          template: "default",
          start_date: "2024-09-27",
          end_date: "2024-10-05"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)
      assert html =~ "Test Theme"
      assert html =~ "2024"
    end
  end

  describe "GET /biennale/:slug — festival template" do
    test "renders festival biennale with theme and year", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2023",
          theme: "Festival Theme",
          template: "festival",
          start_date: "2023-09-27",
          end_date: "2023-10-05"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)
      assert html =~ "Festival Theme"
      assert html =~ "2023"
    end
  end

  describe "GET /biennale/:slug — festival-2023 template" do
    test "renders festival-2023 biennale", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2022",
          theme: "Orphic Mysteries",
          template: "festival-2023",
          start_date: "2022-09-27",
          end_date: "2022-10-05"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)
      assert html =~ "Orphic Mysteries"
    end
  end

  describe "GET /biennale/:slug — festival-2025 template" do
    test "renders festival-2025 biennale with program and projects", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2026",
          theme: "New Horizons",
          template: "festival-2025",
          start_date: "2026-06-01",
          end_date: "2026-09-30",
          statement: "A statement here."
        )

      _event = ContentFixtures.event_fixture(title: "Festival Event", biennale: biennale)

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)
      assert html =~ "New Horizons"
      assert html =~ "2026"
      assert html =~ "Program 2026"
      assert html =~ "Festival Event"
      assert html =~ "Projects 2026"
    end
  end

  describe "GET /biennale/:slug — none template" do
    test "renders none template with page content", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2021",
          theme: "No Template",
          template: "none"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}"), 200)
      assert html =~ "No Template"
    end
  end

  describe "GET /biennale/:slug/festival" do
    test "renders biennale via festival route", %{conn: conn} do
      biennale =
        ContentFixtures.biennale_fixture(
          year: "2024",
          theme: "Fest Route",
          template: "default"
        )

      html = html_response(get(conn, "/biennale/#{biennale.slug}/festival"), 200)
      assert html =~ "Fest Route"
    end
  end

  describe "GET /biennale/:slug — negative cases" do
    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/biennale/nonexistent")
      assert conn.status == 404
    end

    test "404 for invisible biennale", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(visible: false)
      conn = get(conn, "/biennale/#{biennale.slug}")
      assert conn.status == 404
    end

    test "404 for non-biennale entity slug", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture()
      conn = get(conn, "/biennale/#{artwork.slug}")
      assert conn.status == 404
    end
  end
end
