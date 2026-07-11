defmodule MykonosBiennaleWeb.Admin.SectionLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists sections", %{conn: conn} do
      _section = SiteFixtures.section_fixture(title: "Test Section Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/sections")
      assert html =~ "Test Section Title"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/sections")
      assert html =~ "/admin/sections/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/sections/new")
      html = lv |> element("#section-form") |> render()
      assert html =~ "title"
    end

    test "creates section on valid submit", %{conn: conn} do
      page = SiteFixtures.page_fixture()
      {:ok, lv, _html} = live(conn, ~p"/admin/sections/new")

      lv
      |> form("#section-form",
        section: %{title: "New Section", page_id: page.id, content: "<p>Hello</p>"}
      )
      |> render_submit()

      html = render(lv)
      assert html =~ "New Section"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Edit Section Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/sections/#{section.id}/edit")
      html = lv |> element("#section-form") |> render()
      assert html =~ "Edit Section Title"
    end

    test "updates section on valid submit", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Old Section Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/sections/#{section.id}/edit")

      lv
      |> form("#section-form", section: %{title: "Updated Section"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/sections")
    end
  end

  describe "Show" do
    test "renders section details", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Show Section Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/sections/#{section.id}")
      assert html =~ "Show Section Title"
    end
  end

  describe "Delete" do
    test "deletes section from index", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Delete Section")
      {:ok, lv, _html} = live(conn, ~p"/admin/sections")
      lv |> element("[phx-click=delete][phx-value-id='#{section.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Section")
    end
  end
end
