defmodule MykonosBiennaleWeb.Admin.ArtworkLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists artworks", %{conn: conn} do
      _artwork = ContentFixtures.artwork_fixture(title: "Test Artwork Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks")
      assert html =~ "Test Artwork Title"
    end

    test "has + New and Merge links", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks")
      assert html =~ "/admin/artworks/new"
      assert html =~ "/admin/artworks/merge"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")
      html = lv |> element("#artwork-form") |> render()
      assert html =~ "title"
    end

    test "creates artwork on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")

      lv
      |> form("#artwork-form", artwork: %{title: "New Artwork"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/artworks")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")

      html =
        lv
        |> form("#artwork-form", artwork: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Edit Artwork")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/#{artwork.id}/edit")
      html = lv |> element("#artwork-form") |> render()
      assert html =~ "Edit Artwork"
    end

    test "updates artwork on valid submit", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Old Artwork Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/#{artwork.id}/edit")

      lv
      |> form("#artwork-form", artwork: %{title: "Updated Artwork"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/artworks")
    end
  end

  describe "Show" do
    test "renders artwork details", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Show Artwork")
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/#{artwork.id}")
      assert html =~ "Show Artwork"
    end
  end

  describe "Delete" do
    test "deletes artwork from index", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Delete Artwork")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks")
      lv |> element("[phx-click=delete][phx-value-id='#{artwork.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Artwork")
    end
  end

  describe "Merge" do
    test "mounts merge page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/merge")
      assert html =~ "Merge Duplicate Artworks"
    end
  end

  describe "Reimport Preview" do
    setup do
      dir = Path.join(File.cwd!(), "exports/festival")
      File.mkdir_p!(dir)
      path = Path.join(dir, "records.json")
      File.write!(path, Jason.encode!([]))
      on_exit(fn -> File.rm(path) end)
      :ok
    end

    test "mounts reimport preview page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/import_preview")
      assert html =~ "Artwork Reimport Preview"
    end
  end
end
