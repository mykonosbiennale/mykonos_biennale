defmodule MykonosBiennaleWeb.Admin.SEOSectionTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo

  setup %{conn: conn} do
    artwork = ContentFixtures.artwork_fixture(title: "Old Artwork Title")
    {:ok, lv, _html} = live(conn, ~p"/admin/artworks/#{artwork.id}/edit")
    {:ok, artwork: artwork, lv: lv}
  end

  test "the SEO section is pre-filled from the entity", %{lv: lv} do
    html = lv |> element("#seo-section") |> render()

    assert html =~ ~s(name="seo[title]")
    assert html =~ ~s(value="Old Artwork Title")
  end

  test "saving a changed SEO title stores an override", %{lv: lv, artwork: artwork} do
    lv
    |> form("#artwork-form",
      artwork: %{title: "Old Artwork Title"},
      seo: %{title: "Custom search title"}
    )
    |> render_submit()

    assert Repo.get!(Entity, artwork.id).seo == %{"title" => "Custom search title"}
  end

  test "saving unchanged SEO values stores nothing", %{lv: lv, artwork: artwork} do
    lv
    |> form("#artwork-form",
      artwork: %{title: "Old Artwork Title"},
      seo: %{title: "Old Artwork Title"}
    )
    |> render_submit()

    assert Repo.get!(Entity, artwork.id).seo == %{}
  end
end
