defmodule MykonosBiennaleWeb.PublicSearchLiveTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Search.Indexer

  test "mounts /search with empty state", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/search")
    assert html =~ "Search"
    assert html =~ "Type a name, work, or theme to begin."
  end

  test "search returns results for indexed entity", %{conn: conn} do
    artwork = ContentFixtures.artwork_fixture(title: "Searchable Artwork")
    Indexer.index_entity(artwork.id)

    {:ok, _lv, html} = live(conn, ~p"/search?q=Searchable")
    assert html =~ "Searchable Artwork"
    assert html =~ ~s(href="/art/#{artwork.id}")
  end

  test "search shows no results message for unknown query", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/search?q=zzznonexistent")
    assert html =~ "No results"
  end

  test "search event updates results via push_patch", %{conn: conn} do
    artwork = ContentFixtures.artwork_fixture(title: "Patch Test Artwork")
    Indexer.index_entity(artwork.id)

    {:ok, lv, _html} = live(conn, ~p"/search")

    lv |> render_hook("search", %{"q" => "Patch Test"})

    html = render(lv)
    assert html =~ "Patch Test Artwork"
  end
end
