defmodule MykonosBiennaleWeb.EventControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /event/:id — exhibition template" do
    test "renders exhibition event with title, location, date, and description", %{conn: conn} do
      event =
        ContentFixtures.event_fixture(
          title: "Gallery Opening",
          type: "exhibition",
          location: "Main Hall",
          date: "2025-09-28",
          description: "A grand exhibition."
        )

      html = html_response(get(conn, "/event/#{event.id}"), 200)
      assert html =~ "Gallery Opening"
      assert html =~ "Main Hall"
      assert html =~ "Sep 28, 2025"
      assert html =~ "A grand exhibition."
    end

    test "renders Artworks section for exhibition", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Show", type: "exhibition")
      artwork = ContentFixtures.artwork_fixture(title: "Exhibited Piece")
      ContentFixtures.link_artwork_to_event(artwork, event)

      html = html_response(get(conn, "/event/#{event.id}"), 200)
      assert html =~ "Artworks"
      assert html =~ "Exhibited Piece"
    end
  end

  describe "GET /event/:id — screening template" do
    test "renders screening event with film selection", %{conn: conn} do
      event =
        ContentFixtures.event_fixture(
          title: "Film Night",
          type: "screening",
          location: "Outdoor Cinema",
          date: "2025-09-30"
        )

      film = ContentFixtures.film_fixture(title: "Test Film")
      ContentFixtures.link_film_to_event(film, event)

      html = html_response(get(conn, "/event/#{event.id}"), 200)
      assert html =~ "Film Night"
      assert html =~ "Outdoor Cinema"
      assert html =~ "Official Film Selection"
      assert html =~ "Test Film"
    end
  end

  describe "GET /event/:id — default template" do
    test "renders generic event with title and location", %{conn: conn} do
      event =
        ContentFixtures.simple_event_fixture(
          title: "Workshop Day",
          type: "workshop",
          location: "Studio A",
          date: "2025-10-01",
          description: "A hands-on workshop."
        )

      html = html_response(get(conn, "/event/#{event.id}"), 200)
      assert html =~ "Workshop Day"
      assert html =~ "Studio A"
      assert html =~ "A hands-on workshop."
    end
  end

  describe "GET /event/:id — negative cases" do
    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/event/999999")
      assert conn.status == 404
    end

    test "404 for invisible event", %{conn: conn} do
      event = ContentFixtures.event_fixture(visible: false)
      conn = get(conn, "/event/#{event.id}")
      assert conn.status == 404
    end

    test "404 for non-event entity type", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture()
      conn = get(conn, "/event/#{artwork.id}")
      assert conn.status == 404
    end
  end

  describe "GET /event/s/:slug" do
    test "renders event by slug", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Slug Event", type: "exhibition")
      html = html_response(get(conn, "/event/s/#{event.slug}"), 200)
      assert html =~ "Slug Event"
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/event/s/nonexistent-slug")
      assert conn.status == 404
    end
  end
end
