defmodule MykonosBiennaleWeb.GoldenSmokeTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.Entity

  setup do
    ids = MykonosBiennale.GoldenFixtures.load_golden_data!()
    %{golden: ids}
  end

  describe "artwork page /art/:id" do
    test "renders title, linked participant, media, and exhibited-at event", %{
      conn: conn,
      golden: ids
    } do
      html = html_response(get(conn, "/art/#{ids.artwork}"), 200)

      assert html =~ "collection — Mykonos Biennale"
      assert html =~ ~s(<h1 class="text-4xl md:text-5xl font-light text-white mb-2">)
      assert html =~ "collection"
      assert html =~ ~s(href="/artist/3362")
      assert html =~ "Max Brismontier"

      assert html =~ "Exhibited at"
      assert html =~ "Mystic Garden"
    end

    test "404 for unknown artwork id", %{conn: conn} do
      conn = get(conn, "/art/999999")
      assert conn.status == 404
    end

    test "404 for non-artwork entity type", %{conn: conn, golden: ids} do
      conn = get(conn, "/art/#{ids.artist}")
      assert conn.status == 404
    end
  end

  describe "artist page /artist/:id" do
    test "renders artist name and linked artworks", %{conn: conn, golden: ids} do
      html = html_response(get(conn, "/artist/#{ids.artist}"), 200)

      assert html =~ "Anna Molloy — Mykonos Biennale"
      assert html =~ ~s(<h1 class="text-4xl md:text-5xl font-light text-white mb-2">)
      assert html =~ "Anna Molloy"

      assert html =~ "Mykonos Biennale 2025"
      assert html =~ "9 THE AMPHIBIAN"
      assert html =~ ~s(href="/art/3357")
      assert html =~ "Garden of Mysteries"

      assert html =~ "Mykonos Biennale 2023"
      assert html =~ "Orphic Mysteries"
      assert html =~ ~s(href="/art/2996")
      assert html =~ "Laterns, 2023"
    end

    test "404 for unknown participant id", %{conn: conn} do
      conn = get(conn, "/artist/999999")
      assert conn.status == 404
    end
  end

  describe "exhibition event page /event/:id" do
    test "renders title, location, date, description, and biennale breadcrumb", %{
      conn: conn,
      golden: ids
    } do
      html = html_response(get(conn, "/event/#{ids.exhibition_event}"), 200)

      assert html =~ "Mystic Garden — Mykonos Biennale"
      assert html =~ "Mystic Garden"
      assert html =~ "YELLOW TOWER, ANO MERA, MYKONOS"
      assert html =~ "Sep 27, 2025"

      assert html =~
               "An installation of works in the old garden of the Venieri house in Ano Mera."

      assert html =~ ~s(href="/biennale/2025")
      assert html =~ "Mykonos Biennale 2025"
    end

    test "404 for unknown event id", %{conn: conn} do
      conn = get(conn, "/event/999999")
      assert conn.status == 404
    end
  end

  describe "screening event page /event/:id" do
    test "renders title, location, date, and film selection", %{conn: conn, golden: ids} do
      html = html_response(get(conn, "/event/#{ids.screening_event}"), 200)

      assert html =~ "DRAMATIC NIGHTS SCREENING DAY 1 — Mykonos Biennale"
      assert html =~ "DRAMATIC NIGHTS SCREENING DAY 1"
      assert html =~ "YELLOW TOWER, ANO MERA"
      assert html =~ "Sep 27, 2023"

      assert html =~ "Official Film Selection"
      assert html =~ "AGALLIASI"
      assert html =~ "Arm Wrestler"
    end
  end

  describe "biennale page /biennale/:slug" do
    test "renders hero with theme, year, statement, program, projects, and archive", %{
      conn: conn
    } do
      html = html_response(get(conn, "/biennale/2025"), 200)

      assert html =~ "MYKONOS BIENNALE"
      assert html =~ "9 THE AMPHIBIAN"
      assert html =~ "2025"

      assert html =~ "Program 2025"
      assert html =~ ~s(href="/event/2956")
      assert html =~ "Mystic Garden"

      assert html =~ "Projects 2025"
      assert html =~ "Archive"
    end

    test "festival route renders the same template", %{conn: conn} do
      html = html_response(get(conn, "/biennale/2025/festival"), 200)
      assert html =~ "MYKONOS BIENNALE"
      assert html =~ "9 THE AMPHIBIAN"
    end

    test "404 for unknown biennale slug", %{conn: conn} do
      conn = get(conn, "/biennale/nonexistent")
      assert conn.status == 404
    end
  end

  describe "slug-based routes" do
    test "artwork by slug renders same content as by id", %{conn: conn, golden: ids} do
      artwork = Repo.get!(Entity, ids.artwork)
      html = html_response(get(conn, "/art/s/#{artwork.slug}"), 200)
      assert html =~ "collection"
    end

    test "artist by slug renders same content as by id", %{conn: conn, golden: ids} do
      artist = Repo.get!(Entity, ids.artist)
      html = html_response(get(conn, "/artist/s/#{artist.slug}"), 200)
      assert html =~ "Anna Molloy"
    end

    test "event by slug renders same content as by id", %{conn: conn, golden: ids} do
      event = Repo.get!(Entity, ids.exhibition_event)
      html = html_response(get(conn, "/event/s/#{event.slug}"), 200)
      assert html =~ "Mystic Garden"
    end
  end
end
