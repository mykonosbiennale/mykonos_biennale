defmodule MykonosBiennaleWeb.Admin.PageLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists pages", %{conn: conn} do
      _page = SiteFixtures.page_fixture(title: "Test Page Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/pages")
      assert html =~ "Test Page Title"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/pages")
      assert html =~ "/admin/pages/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/pages/new")
      html = lv |> element("#page-form") |> render()
      assert html =~ "title"
      assert html =~ "slug"
    end

    test "creates page on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/pages/new")

      lv
      |> form("#page-form", page: %{title: "New Page", content: "<p>Hello</p>"})
      |> render_submit()

      html = render(lv)
      assert html =~ "New Page"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Edit Page Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/pages/#{page.id}/edit")
      html = lv |> element("#page-form") |> render()
      assert html =~ "Edit Page Title"
    end

    test "updates page on valid submit", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Old Page Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/pages/#{page.id}/edit")

      lv
      |> form("#page-form", page: %{title: "Updated Page"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/pages")
    end
  end

  describe "Show" do
    test "renders page details", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Show Page Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/pages/#{page.id}")
      assert html =~ "Show Page Title"
    end
  end

  describe "Delete" do
    test "deletes page from index", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Delete Page")
      {:ok, lv, _html} = live(conn, ~p"/admin/pages")
      lv |> element("[phx-click=delete][phx-value-id='#{page.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Page")
    end
  end
end
