defmodule MykonosBiennaleWeb.Admin.FilmLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists films", %{conn: conn} do
      _film = ContentFixtures.film_fixture(title: "Test Film Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/films")
      assert html =~ "Test Film Title"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/films")
      assert html =~ "/admin/films/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")
      html = lv |> element("#film-form") |> render()
      assert html =~ "title"
    end

    test "creates film on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")

      lv
      |> form("#film-form", film: %{title: "New Film", type: "Short Film"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/films")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")

      html =
        lv
        |> form("#film-form", film: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Edit Film")
      {:ok, lv, _html} = live(conn, ~p"/admin/films/#{film.id}/edit")
      html = lv |> element("#film-form") |> render()
      assert html =~ "Edit Film"
    end

    test "updates film on valid submit", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Old Film Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/films/#{film.id}/edit")

      lv
      |> form("#film-form", film: %{title: "Updated Film"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/films")
    end
  end

  describe "Show" do
    test "renders film details", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Show Film")
      {:ok, _lv, html} = live(conn, ~p"/admin/films/#{film.id}")
      assert html =~ "Show Film"
    end
  end

  describe "Delete" do
    test "deletes film from index", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Delete Film")
      {:ok, lv, _html} = live(conn, ~p"/admin/films")
      lv |> element("[phx-click=delete][phx-value-id='#{film.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Film")
    end
  end
end
