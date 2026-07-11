defmodule MykonosBiennaleWeb.Admin.MediaLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists media", %{conn: conn} do
      _media = ContentFixtures.media_fixture(caption: "Test Media Caption")
      {:ok, _lv, html} = live(conn, ~p"/admin/media")
      assert html =~ "Test Media Caption"
    end

    test "has Add Media link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media")
      assert html =~ "/admin/media/new"
    end
  end

  describe "New" do
    test "renders form with caption and source_type fields", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/media/new")
      html = lv |> element("#media-form") |> render()
      assert html =~ "caption"
      assert html =~ "source_type"
    end
  end

  describe "Edit" do
    test "renders form with existing caption", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Edit Media Caption")
      {:ok, lv, _html} = live(conn, ~p"/admin/media/#{media.id}/edit")
      html = lv |> element("#media-form") |> render()
      assert html =~ "Edit Media Caption"
    end

    test "updates media caption on valid submit", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Old Caption")
      {:ok, lv, _html} = live(conn, ~p"/admin/media/#{media.id}/edit")

      html =
        lv
        |> form("#media-form", media: %{caption: "Updated Caption"})
        |> render_submit()

      assert html =~ "Updated Caption"
    end
  end

  describe "Show" do
    test "renders media details", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Show Media")
      {:ok, _lv, html} = live(conn, ~p"/admin/media/#{media.id}")
      assert html =~ "Show Media"
    end
  end

  describe "Rotate" do
    test "mounts batch rotate page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media/rotate")
      assert html =~ "Batch Rotate Media"
    end
  end
end
