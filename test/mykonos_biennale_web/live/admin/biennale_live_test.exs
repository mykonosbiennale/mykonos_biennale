defmodule MykonosBiennaleWeb.Admin.BiennaleLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists biennales", %{conn: conn} do
      __biennale = ContentFixtures.biennale_fixture(year: 2024, theme: "Test Biennale")
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales")
      assert html =~ "Test Biennale"
      assert html =~ "2024"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales")
      assert html =~ "/admin/biennales/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")
      html = lv |> element("#biennale-form") |> render()
      assert html =~ "year"
      assert html =~ "theme"
    end

    test "creates biennale on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")

      html =
        lv
        |> form("#biennale-form", biennale: %{year: 2026, theme: "New Theme"})
        |> render_submit()

      assert html =~ "created successfully"
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")

      html =
        lv
        |> form("#biennale-form", biennale: %{year: nil, theme: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2023, theme: "Old Theme")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/#{biennale.id}/edit")
      html = lv |> element("#biennale-form") |> render()
      assert html =~ "Old Theme"
    end

    test "updates biennale on valid submit", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2023, theme: "Old Theme")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/#{biennale.id}/edit")

      lv
      |> form("#biennale-form", biennale: %{theme: "Updated Theme"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/biennales")
    end
  end

  describe "Show" do
    test "renders biennale details", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Show Theme")
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales/#{biennale.id}")
      assert html =~ "Show Theme"
      assert html =~ "2025"
    end
  end

  describe "Delete" do
    test "deletes biennale from index", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2022, theme: "Delete Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales")
      lv |> element("[phx-click=delete][phx-value-id='#{biennale.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Me")
    end
  end
end
