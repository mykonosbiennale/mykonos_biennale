defmodule MykonosBiennaleWeb.ArtworkControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /art/:id" do
    test "renders bare artwork with title", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Bare Artwork")
      conn = get(conn, "/art/#{artwork.id}")
      html = html_response(conn, 200)
      assert html =~ "Bare Artwork"
    end

    test "renders artwork with media, linked participant, and exhibited-at event", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Pablo", last_name: "Picasso")
      artwork = ContentFixtures.artwork_fixture(title: "Guernica", date: "2025")
      media = ContentFixtures.media_fixture()
      ContentFixtures.attach_media(artwork, media)
      ContentFixtures.link_artwork_to_participant(artwork, participant)
      event = ContentFixtures.event_fixture(title: "Big Show", type: "exhibition")
      ContentFixtures.link_artwork_to_event(artwork, event)

      html = html_response(get(conn, "/art/#{artwork.id}"), 200)
      assert html =~ "Guernica"
      assert html =~ ~s(href="/artist/#{participant.id}")
      assert html =~ "Pablo Picasso"
      assert html =~ "Exhibited at"
      assert html =~ "Big Show"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/art/999999")
      assert conn.status == 404
    end

    test "404 for non-artwork entity type", %{conn: conn} do
      participant = ContentFixtures.participant_fixture()
      conn = get(conn, "/art/#{participant.id}")
      assert conn.status == 404
    end

    test "404 for invisible artwork", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(visible: false)
      conn = get(conn, "/art/#{artwork.id}")
      assert conn.status == 404
    end
  end

  describe "GET /art/s/:slug" do
    test "renders artwork by slug", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Slug Artwork")
      html = html_response(get(conn, "/art/s/#{artwork.slug}"), 200)
      assert html =~ "Slug Artwork"
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/art/s/nonexistent-slug")
      assert conn.status == 404
    end
  end
end
