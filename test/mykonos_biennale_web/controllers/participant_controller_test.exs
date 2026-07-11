defmodule MykonosBiennaleWeb.ParticipantControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /artist/:id" do
    test "renders bare participant with name", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Jane", last_name: "Doe")
      html = html_response(get(conn, "/artist/#{participant.id}"), 200)
      assert html =~ "Jane Doe"
    end

    test "renders participant with country, bio, and artworks", %{conn: conn} do
      participant =
        ContentFixtures.participant_fixture(
          first_name: "Anna",
          last_name: "Smith",
          country: "Greece",
          bio: "A talented artist."
        )

      artwork = ContentFixtures.artwork_fixture(title: "My Work", date: "2025")
      ContentFixtures.link_artwork_to_participant(artwork, participant)

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)
      assert html =~ "Anna Smith"
      assert html =~ "Greece"
      assert html =~ "A talented artist."
      assert html =~ "Works"
      assert html =~ ~s(href="/art/#{artwork.id}")
      assert html =~ "My Work"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/artist/999999")
      assert conn.status == 404
    end

    test "404 for non-participant entity type", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture()
      conn = get(conn, "/artist/#{artwork.id}")
      assert conn.status == 404
    end

    test "404 for invisible participant", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(visible: false)
      conn = get(conn, "/artist/#{participant.id}")
      assert conn.status == 404
    end
  end

  describe "GET /artist/s/:slug" do
    test "renders participant by slug", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Slug", last_name: "Artist")
      html = html_response(get(conn, "/artist/s/#{participant.slug}"), 200)
      assert html =~ "Slug Artist"
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/artist/s/nonexistent-slug")
      assert conn.status == 404
    end
  end
end
