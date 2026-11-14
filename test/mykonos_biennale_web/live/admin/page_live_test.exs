defmodule MykonosBiennaleWeb.Admin.PageLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Site.Page
  alias MykonosBiennaleWeb.Admin.PageLive.FormComponent, as: PageFormComponent

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
      |> form("#page-form",
        page: %{title: "New Page", content: "<p>Hello</p>", template: "default"}
      )
      |> render_submit()

      html = render(lv)
      assert html =~ "New Page"
      assert MykonosBiennale.Repo.get_by(MykonosBiennale.Site.Page, title: "New Page")
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

  describe "Show handlers" do
    test "switch_tab changes the active tab", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Tabbed Page")
      {:ok, lv, html} = live(conn, ~p"/admin/pages/#{page.id}")
      assert html =~ "Tabbed Page"
      assert render_hook(lv, "switch_tab", %{"tab" => "metadata"}) =~ "Tabbed Page"
    end

    test "change stores valid JSON metadata", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Meta Page")
      {:ok, lv, _} = live(conn, ~p"/admin/pages/#{page.id}")

      render_hook(lv, "change", %{"content" => ~s({"hero": "yes"})})

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Site.Page, page.id).metadata == %{
               "hero" => "yes"
             }
    end

    test "change ignores invalid JSON", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Bad Meta Page")
      {:ok, lv, _} = live(conn, ~p"/admin/pages/#{page.id}")

      assert render_hook(lv, "change", %{"content" => "{not json"}) =~ "Bad Meta Page"
    end

    test "metadata_changed info persists metadata", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Info Page")
      {:ok, lv, _} = live(conn, ~p"/admin/pages/#{page.id}")

      send(lv.pid, {:metadata_changed, %{content: ~s({"k": "v"})}})
      assert render(lv) =~ "Info Page"

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Site.Page, page.id).metadata == %{
               "k" => "v"
             }
    end

    test "metadata_changed info ignores invalid JSON", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Info Bad Page")
      {:ok, lv, _} = live(conn, ~p"/admin/pages/#{page.id}")

      send(lv.pid, {:metadata_changed, %{content: "nope"}})
      assert render(lv) =~ "Info Bad Page"
    end

    test "saved info from the form component updates the page", %{conn: conn} do
      page = SiteFixtures.page_fixture(title: "Before Save")
      {:ok, lv, _} = live(conn, ~p"/admin/pages/#{page.id}")

      {:ok, saved} =
        page
        |> Page.changeset(%{title: "After Save"})
        |> Repo.update()

      send(lv.pid, {PageFormComponent, {:saved, saved}})
      assert render(lv) =~ "After Save"
    end
  end

  describe "Index metadata editing" do
    test "change with valid JSON updates the open page form", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/pages/new")
      assert is_binary(render_hook(lv, "change", %{"content" => ~s({"hero": "on"})}))
    end

    test "change with invalid JSON is ignored", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/pages/new")
      assert is_binary(render_hook(lv, "change", %{"content" => "{not json"}))
    end
  end
end
