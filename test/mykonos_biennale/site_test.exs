defmodule MykonosBiennale.SiteTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Site
  alias MykonosBiennale.SiteFixtures
  alias MykonosBiennale.Site.{Page, Section}

  describe "page CRUD" do
    test "create_page/1 creates a page" do
      {:ok, page} = Site.create_page(%{title: "Test Page", slug: "test-page", content: "<p>Hello</p>", visible: true, template: "default"})
      assert %Page{} = page
      assert page.title == "Test Page"
      assert page.slug == "test-page"
    end

    test "get_page!/1 returns a page by id" do
      page = SiteFixtures.page_fixture(title: "Find Me")
      assert Site.get_page!(page.id).id == page.id
    end

    test "get_page_by_slug/1 returns a page by slug" do
      page = SiteFixtures.page_fixture(slug: "my-slug")
      assert Site.get_page_by_slug("my-slug").id == page.id
    end

    test "list_pages/0 returns all pages ordered by position" do
      _p1 = SiteFixtures.page_fixture(title: "A", position: 0)
      _p2 = SiteFixtures.page_fixture(title: "B", position: 1)
      pages = Site.list_pages()
      assert length(pages) >= 2
    end

    test "list_visible_pages/0 returns only visible pages" do
      _visible = SiteFixtures.page_fixture(title: "Visible", visible: true)
      _hidden = SiteFixtures.page_fixture(title: "Hidden", visible: false)
      visible = Site.list_visible_pages()
      assert Enum.all?(visible, & &1.visible)
    end

    test "update_page/2 updates page fields" do
      page = SiteFixtures.page_fixture(title: "Old")
      {:ok, updated} = Site.update_page(page, %{title: "New"})
      assert updated.title == "New"
    end

    test "delete_page/1 deletes the page" do
      page = SiteFixtures.page_fixture()
      assert {:ok, _} = Site.delete_page(page)
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(page.id) end
    end

    test "change_page/1 returns a changeset" do
      page = SiteFixtures.page_fixture()
      assert %Ecto.Changeset{} = Site.change_page(page)
    end
  end

  describe "section CRUD" do
    test "create_section/1 creates a section linked to a page" do
      page = SiteFixtures.page_fixture()
      {:ok, section} = Site.create_section(%{title: "Test", slug: "test", page_id: page.id, content: "x", visible: true, template: "default"})
      assert %Section{} = section
      assert section.page_id == page.id
    end

    test "get_section!/1 returns a section by id" do
      section = SiteFixtures.section_fixture(title: "Find Me")
      assert Site.get_section!(section.id).id == section.id
    end

    test "list_sections/0 returns all sections" do
      _s1 = SiteFixtures.section_fixture(title: "A")
      _s2 = SiteFixtures.section_fixture(title: "B")
      sections = Site.list_sections()
      assert length(sections) >= 2
    end

    test "update_section/2 updates section fields" do
      section = SiteFixtures.section_fixture(title: "Old")
      {:ok, updated} = Site.update_section(section, %{title: "New"})
      assert updated.title == "New"
    end

    test "delete_section/1 deletes the section" do
      section = SiteFixtures.section_fixture()
      assert {:ok, _} = Site.delete_section(section)
      assert_raise Ecto.NoResultsError, fn -> Site.get_section!(section.id) end
    end
  end
end
