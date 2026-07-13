defmodule MykonosBiennaleWeb.FilmControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  describe "GET /film/:id" do
    test "renders film with title, director, runtime, and log_line", %{conn: conn} do
      film =
        ContentFixtures.film_fixture(
          title: "Test Film",
          dir_by: "Jane Director",
          country: "Greece",
          runtime: 12,
          log_line: "A story about the sea."
        )

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Test Film"
      assert html =~ "Jane Director"
      assert html =~ "Greece"
      assert html =~ "12 min"
      assert html =~ "A story about the sea."
    end

    test "renders poster when present", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Poster Film")
      media = ContentFixtures.media_fixture(caption: "Film Poster")
      ContentFixtures.attach_media(film, media, metadata: %{"role" => "poster"})

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Poster Film"
    end

    test "renders crew credits grouped by role", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Crew Film")
      director = ContentFixtures.participant_fixture(first_name: "Jane", last_name: "Director")
      editor = ContentFixtures.participant_fixture(first_name: "John", last_name: "Editor")
      ContentFixtures.create_relationship(film, director, "directed")
      ContentFixtures.create_relationship(film, editor, "edited")

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Credits"
      assert html =~ "directed"
      assert html =~ "Jane Director"
      assert html =~ "edited"
      assert html =~ "John Editor"
    end

    test "links crew members to artist pages", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Link Film")
      director = ContentFixtures.participant_fixture(first_name: "Dir", last_name: "Person")
      ContentFixtures.create_relationship(film, director, "directed")

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ ~s(href="/artist/#{director.id}")
    end

    test "shows screened-at events", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)

      event =
        ContentFixtures.event_fixture(
          title: "Screening Night",
          type: "screening",
          biennale: biennale
        )

      film = ContentFixtures.film_fixture(title: "Screened Film")
      ContentFixtures.link_film_to_event(film, event)

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Screened at"
      assert html =~ "Screening Night"
    end

    test "shows biennale breadcrumb when event has biennale", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Test Theme")
      event = ContentFixtures.event_fixture(title: "Event", type: "screening", biennale: biennale)
      film = ContentFixtures.film_fixture(title: "Breadcrumb Film")
      ContentFixtures.link_film_to_event(film, event)

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ ~s(href="/biennale/#{biennale.slug}")
      assert html =~ "Mykonos Biennale 2025"
    end

    test "renders trailer embed when present", %{conn: conn} do
      film =
        ContentFixtures.film_fixture(
          title: "Trailer Film",
          trailer_embed: ~s(<iframe src="https://www.youtube.com/embed/abc123"></iframe>)
        )

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Trailer"
      assert html =~ "youtube.com/embed/abc123"
    end

    test "renders trailer link when trailer_url present and no embed", %{conn: conn} do
      film =
        ContentFixtures.film_fixture(
          title: "Trailer Link Film",
          trailer_url: "https://youtu.be/xyz789"
        )

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Trailer"
      assert html =~ ~s(href="https://youtu.be/xyz789")
      assert html =~ "Watch trailer"
    end

    test "renders stills section with screenshot media", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Stills Film")
      screenshot = ContentFixtures.media_fixture(caption: "Scene 1")
      ContentFixtures.attach_media(film, screenshot, metadata: %{"role" => "screenshot"})

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Stills"
      assert html =~ "Scene 1"
    end

    test "does not render duplicate or exposed img attributes", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Clean HTML Film")
      screenshot = ContentFixtures.media_fixture(caption: "Clean Shot")
      ContentFixtures.attach_media(film, screenshot, metadata: %{"role" => "screenshot"})

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      refute html =~ ~s(/> loading=)
      refute html =~ ~s(loading="eager" /> loading=)
    end

    test "does not show poster in stills section", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "No Poster In Stills")
      poster = ContentFixtures.media_fixture(caption: "The Poster")
      screenshot = ContentFixtures.media_fixture(caption: "The Screenshot")
      ContentFixtures.attach_media(film, poster, metadata: %{"role" => "poster"})
      ContentFixtures.attach_media(film, screenshot, metadata: %{"role" => "screenshot"})

      html = html_response(get(conn, "/film/#{film.id}"), 200)
      assert html =~ "Stills"
      assert html =~ "The Screenshot"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/film/999999")
      assert conn.status == 404
    end

    test "404 for non-film entity type", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture()
      conn = get(conn, "/film/#{artwork.id}")
      assert conn.status == 404
    end

    test "404 for invisible film", %{conn: conn} do
      film = ContentFixtures.film_fixture(visible: false)
      conn = get(conn, "/film/#{film.id}")
      assert conn.status == 404
    end
  end

  describe "GET /film/s/:slug" do
    test "renders film by slug", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Slug Film")
      html = html_response(get(conn, "/film/s/#{film.slug}"), 200)
      assert html =~ "Slug Film"
    end

    test "404 for unknown slug", %{conn: conn} do
      conn = get(conn, "/film/s/nonexistent-slug")
      assert conn.status == 404
    end
  end
end
