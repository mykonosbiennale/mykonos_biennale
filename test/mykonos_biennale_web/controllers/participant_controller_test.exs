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

      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Test Theme")

      event =
        ContentFixtures.event_fixture(title: "Show Event", type: "exhibition", biennale: biennale)

      artwork = ContentFixtures.artwork_fixture(title: "My Work", date: "2025")
      ContentFixtures.link_artwork_to_participant(artwork, participant)
      ContentFixtures.link_artwork_to_event(artwork, event)

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)
      assert html =~ "Anna Smith"
      assert html =~ "Greece"
      assert html =~ "A talented artist."
      assert html =~ "Mykonos Biennale 2025"
      assert html =~ "Test Theme"
      assert html =~ ~s(href="/art/#{artwork.id}")
      assert html =~ "My Work"
    end

    test "groups works by biennale with year and theme headers", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Group", last_name: "Test")

      biennale_2025 = ContentFixtures.biennale_fixture(year: 2025, theme: "Amphibian")
      biennale_2023 = ContentFixtures.biennale_fixture(year: 2023, theme: "Orphic")

      event_2025 =
        ContentFixtures.event_fixture(
          title: "2025 Show",
          type: "exhibition",
          biennale: biennale_2025
        )

      event_2023 =
        ContentFixtures.event_fixture(
          title: "2023 Show",
          type: "exhibition",
          biennale: biennale_2023
        )

      artwork_2025 = ContentFixtures.artwork_fixture(title: "New Work")
      ContentFixtures.link_artwork_to_participant(artwork_2025, participant)
      ContentFixtures.link_artwork_to_event(artwork_2025, event_2025)

      artwork_2023 = ContentFixtures.artwork_fixture(title: "Old Work")
      ContentFixtures.link_artwork_to_participant(artwork_2023, participant)
      ContentFixtures.link_artwork_to_event(artwork_2023, event_2023)

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)

      assert html =~ "Mykonos Biennale 2025"
      assert html =~ "Amphibian"
      assert html =~ "New Work"

      assert html =~ "Mykonos Biennale 2023"
      assert html =~ "Orphic"
      assert html =~ "Old Work"
    end

    test "shows each film once with all roles listed, using identity as title", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Film", last_name: "Maker")

      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Film Theme")

      event =
        ContentFixtures.event_fixture(
          title: "Screening Night",
          type: "screening",
          biennale: biennale
        )

      film = ContentFixtures.film_fixture(title: "Corrosion")
      ContentFixtures.link_film_to_event(film, event)
      ContentFixtures.create_relationship(film, participant, "directed")
      ContentFixtures.create_relationship(film, participant, "edited")
      ContentFixtures.create_relationship(film, participant, "screenwrote")

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)

      assert html =~ "Corrosion"
      assert html =~ "Short Film"
      assert html =~ "directed"
      assert html =~ "edited"
      assert html =~ "screenwrote"

      assert html =~ ~s(href="/film/#{film.id}")
      refute html =~ ~s(href="/art/#{film.id}")

      matches = Regex.scan(~r/Corrosion/, html)
      assert length(matches) == 1, "film should appear once, not #{length(matches)} times"
    end

    test "shows artwork and film in the same biennale group", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Multi", last_name: "Artist")

      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Mixed")

      event =
        ContentFixtures.event_fixture(title: "Mixed Show", type: "exhibition", biennale: biennale)

      screening =
        ContentFixtures.event_fixture(
          title: "Mixed Screening",
          type: "screening",
          biennale: biennale
        )

      artwork = ContentFixtures.artwork_fixture(title: "Painting")
      ContentFixtures.link_artwork_to_participant(artwork, participant)
      ContentFixtures.link_artwork_to_event(artwork, event)

      film = ContentFixtures.film_fixture(title: "Short Movie")
      ContentFixtures.link_film_to_event(film, screening)
      ContentFixtures.create_relationship(film, participant, "directed")

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)

      assert html =~ "Mykonos Biennale 2025"
      assert html =~ "Mixed"
      assert html =~ "Painting"
      assert html =~ "Short Movie"
    end

    test "works with no biennale appear in Other Works group", %{conn: conn} do
      participant =
        ContentFixtures.participant_fixture(first_name: "Unlinked", last_name: "Artist")

      artwork = ContentFixtures.artwork_fixture(title: "Orphan Work")
      ContentFixtures.link_artwork_to_participant(artwork, participant)

      html = html_response(get(conn, "/artist/#{participant.id}"), 200)
      assert html =~ "Other Works"
      assert html =~ "Orphan Work"
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
