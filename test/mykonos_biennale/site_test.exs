defmodule MykonosBiennale.SiteTest do
  use MykonosBiennale.DataCase

  alias MykonosBiennale.Site

  describe "pages" do
    alias MykonosBiennale.Site.Page

    import MykonosBiennale.AccountsFixtures, only: [user_scope_fixture: 0]
    import MykonosBiennale.SiteFixtures

    @invalid_attrs %{title: nil, metadata: nil, template: nil, html: nil, slug: nil}

    test "list_pages/1 returns all scoped pages" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)
      other_page = page_fixture(other_scope)
      assert Site.list_pages(scope) == [page]
      assert Site.list_pages(other_scope) == [other_page]
    end

    test "get_page!/2 returns the page with given id" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      other_scope = user_scope_fixture()
      assert Site.get_page!(scope, page.id) == page
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(other_scope, page.id) end
    end

    test "create_page/2 with valid data creates a page" do
      valid_attrs = %{title: "some title", metadata: %{}, template: "some template", html: "some html", slug: "some slug"}
      scope = user_scope_fixture()

      assert {:ok, %Page{} = page} = Site.create_page(scope, valid_attrs)
      assert page.title == "some title"
      assert page.metadata == %{}
      assert page.template == "some template"
      assert page.html == "some html"
      assert page.slug == "some slug"
      assert page.user_id == scope.user.id
    end

    test "create_page/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.create_page(scope, @invalid_attrs)
    end

    test "update_page/3 with valid data updates the page" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      update_attrs = %{title: "some updated title", metadata: %{}, template: "some updated template", html: "some updated html", slug: "some updated slug"}

      assert {:ok, %Page{} = page} = Site.update_page(scope, page, update_attrs)
      assert page.title == "some updated title"
      assert page.metadata == %{}
      assert page.template == "some updated template"
      assert page.html == "some updated html"
      assert page.slug == "some updated slug"
    end

    test "update_page/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)

      assert_raise MatchError, fn ->
        Site.update_page(other_scope, page, %{})
      end
    end

    test "update_page/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Site.update_page(scope, page, @invalid_attrs)
      assert page == Site.get_page!(scope, page.id)
    end

    test "delete_page/2 deletes the page" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert {:ok, %Page{}} = Site.delete_page(scope, page)
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(scope, page.id) end
    end

    test "delete_page/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)
      assert_raise MatchError, fn -> Site.delete_page(other_scope, page) end
    end

    test "change_page/2 returns a page changeset" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert %Ecto.Changeset{} = Site.change_page(scope, page)
    end
  end

  describe "sections" do
    alias MykonosBiennale.Site.Section

    import MykonosBiennale.AccountsFixtures, only: [user_scope_fixture: 0]
    import MykonosBiennale.SiteFixtures

    @invalid_attrs %{visible: nil, title: nil, metadata: nil, slug: nil, content: nil}

    test "list_sections/1 returns all scoped sections" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      section = section_fixture(scope)
      other_section = section_fixture(other_scope)
      assert Site.list_sections(scope) == [section]
      assert Site.list_sections(other_scope) == [other_section]
    end

    test "get_section!/2 returns the section with given id" do
      scope = user_scope_fixture()
      section = section_fixture(scope)
      other_scope = user_scope_fixture()
      assert Site.get_section!(scope, section.id) == section
      assert_raise Ecto.NoResultsError, fn -> Site.get_section!(other_scope, section.id) end
    end

    test "create_section/2 with valid data creates a section" do
      valid_attrs = %{visible: true, title: "some title", metadata: %{}, slug: "some slug", content: "some content"}
      scope = user_scope_fixture()

      assert {:ok, %Section{} = section} = Site.create_section(scope, valid_attrs)
      assert section.visible == true
      assert section.title == "some title"
      assert section.metadata == %{}
      assert section.slug == "some slug"
      assert section.content == "some content"
      assert section.user_id == scope.user.id
    end

    test "create_section/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.create_section(scope, @invalid_attrs)
    end

    test "update_section/3 with valid data updates the section" do
      scope = user_scope_fixture()
      section = section_fixture(scope)
      update_attrs = %{visible: false, title: "some updated title", metadata: %{}, slug: "some updated slug", content: "some updated content"}

      assert {:ok, %Section{} = section} = Site.update_section(scope, section, update_attrs)
      assert section.visible == false
      assert section.title == "some updated title"
      assert section.metadata == %{}
      assert section.slug == "some updated slug"
      assert section.content == "some updated content"
    end

    test "update_section/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      section = section_fixture(scope)

      assert_raise MatchError, fn ->
        Site.update_section(other_scope, section, %{})
      end
    end

    test "update_section/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      section = section_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Site.update_section(scope, section, @invalid_attrs)
      assert section == Site.get_section!(scope, section.id)
    end

    test "delete_section/2 deletes the section" do
      scope = user_scope_fixture()
      section = section_fixture(scope)
      assert {:ok, %Section{}} = Site.delete_section(scope, section)
      assert_raise Ecto.NoResultsError, fn -> Site.get_section!(scope, section.id) end
    end

    test "delete_section/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      section = section_fixture(scope)
      assert_raise MatchError, fn -> Site.delete_section(other_scope, section) end
    end

    test "change_section/2 returns a section changeset" do
      scope = user_scope_fixture()
      section = section_fixture(scope)
      assert %Ecto.Changeset{} = Site.change_section(scope, section)
    end
  end

  describe "pages" do
    alias MykonosBiennale.Site.Page

    import MykonosBiennale.AccountsFixtures, only: [user_scope_fixture: 0]
    import MykonosBiennale.SiteFixtures

    @invalid_attrs %{visible: nil, description: nil, title: nil, metadata: nil, template: nil, slug: nil, content: nil}

    test "list_pages/1 returns all scoped pages" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)
      other_page = page_fixture(other_scope)
      assert Site.list_pages(scope) == [page]
      assert Site.list_pages(other_scope) == [other_page]
    end

    test "get_page!/2 returns the page with given id" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      other_scope = user_scope_fixture()
      assert Site.get_page!(scope, page.id) == page
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(other_scope, page.id) end
    end

    test "create_page/2 with valid data creates a page" do
      valid_attrs = %{visible: true, description: "some description", title: "some title", metadata: %{}, template: :node, slug: "some slug", content: "some content"}
      scope = user_scope_fixture()

      assert {:ok, %Page{} = page} = Site.create_page(scope, valid_attrs)
      assert page.visible == true
      assert page.description == "some description"
      assert page.title == "some title"
      assert page.metadata == %{}
      assert page.template == :node
      assert page.slug == "some slug"
      assert page.content == "some content"
      assert page.user_id == scope.user.id
    end

    test "create_page/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.create_page(scope, @invalid_attrs)
    end

    test "update_page/3 with valid data updates the page" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      update_attrs = %{visible: false, description: "some updated description", title: "some updated title", metadata: %{}, template: :default, slug: "some updated slug", content: "some updated content"}

      assert {:ok, %Page{} = page} = Site.update_page(scope, page, update_attrs)
      assert page.visible == false
      assert page.description == "some updated description"
      assert page.title == "some updated title"
      assert page.metadata == %{}
      assert page.template == :default
      assert page.slug == "some updated slug"
      assert page.content == "some updated content"
    end

    test "update_page/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)

      assert_raise MatchError, fn ->
        Site.update_page(other_scope, page, %{})
      end
    end

    test "update_page/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Site.update_page(scope, page, @invalid_attrs)
      assert page == Site.get_page!(scope, page.id)
    end

    test "delete_page/2 deletes the page" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert {:ok, %Page{}} = Site.delete_page(scope, page)
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(scope, page.id) end
    end

    test "delete_page/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      page = page_fixture(scope)
      assert_raise MatchError, fn -> Site.delete_page(other_scope, page) end
    end

    test "change_page/2 returns a page changeset" do
      scope = user_scope_fixture()
      page = page_fixture(scope)
      assert %Ecto.Changeset{} = Site.change_page(scope, page)
    end
  end

  describe "pages" do
    alias MykonosBiennale.Site.Page

    import MykonosBiennale.SiteFixtures

    @invalid_attrs %{visible: nil, description: nil, title: nil, metadata: nil, template: nil, slug: nil, content: nil}

    test "list_pages/0 returns all pages" do
      page = page_fixture()
      assert Site.list_pages() == [page]
    end

    test "get_page!/1 returns the page with given id" do
      page = page_fixture()
      assert Site.get_page!(page.id) == page
    end

    test "create_page/1 with valid data creates a page" do
      valid_attrs = %{visible: true, description: "some description", title: "some title", metadata: %{}, template: :node, slug: "some slug", content: "some content"}

      assert {:ok, %Page{} = page} = Site.create_page(valid_attrs)
      assert page.visible == true
      assert page.description == "some description"
      assert page.title == "some title"
      assert page.metadata == %{}
      assert page.template == :node
      assert page.slug == "some slug"
      assert page.content == "some content"
    end

    test "create_page/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Site.create_page(@invalid_attrs)
    end

    test "update_page/2 with valid data updates the page" do
      page = page_fixture()
      update_attrs = %{visible: false, description: "some updated description", title: "some updated title", metadata: %{}, template: :default, slug: "some updated slug", content: "some updated content"}

      assert {:ok, %Page{} = page} = Site.update_page(page, update_attrs)
      assert page.visible == false
      assert page.description == "some updated description"
      assert page.title == "some updated title"
      assert page.metadata == %{}
      assert page.template == :default
      assert page.slug == "some updated slug"
      assert page.content == "some updated content"
    end

    test "update_page/2 with invalid data returns error changeset" do
      page = page_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.update_page(page, @invalid_attrs)
      assert page == Site.get_page!(page.id)
    end

    test "delete_page/1 deletes the page" do
      page = page_fixture()
      assert {:ok, %Page{}} = Site.delete_page(page)
      assert_raise Ecto.NoResultsError, fn -> Site.get_page!(page.id) end
    end

    test "change_page/1 returns a page changeset" do
      page = page_fixture()
      assert %Ecto.Changeset{} = Site.change_page(page)
    end
  end

  describe "sections" do
    alias MykonosBiennale.Site.Section

    import MykonosBiennale.SiteFixtures

    @invalid_attrs %{visible: nil, description: nil, title: nil, metadata: nil, template: nil, slug: nil, content: nil}

    test "list_sections/0 returns all sections" do
      section = section_fixture()
      assert Site.list_sections() == [section]
    end

    test "get_section!/1 returns the section with given id" do
      section = section_fixture()
      assert Site.get_section!(section.id) == section
    end

    test "create_section/1 with valid data creates a section" do
      valid_attrs = %{visible: true, description: "some description", title: "some title", metadata: %{}, template: :node, slug: "some slug", content: "some content"}

      assert {:ok, %Section{} = section} = Site.create_section(valid_attrs)
      assert section.visible == true
      assert section.description == "some description"
      assert section.title == "some title"
      assert section.metadata == %{}
      assert section.template == :node
      assert section.slug == "some slug"
      assert section.content == "some content"
    end

    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Site.create_section(@invalid_attrs)
    end

    test "update_section/2 with valid data updates the section" do
      section = section_fixture()
      update_attrs = %{visible: false, description: "some updated description", title: "some updated title", metadata: %{}, template: :default, slug: "some updated slug", content: "some updated content"}

      assert {:ok, %Section{} = section} = Site.update_section(section, update_attrs)
      assert section.visible == false
      assert section.description == "some updated description"
      assert section.title == "some updated title"
      assert section.metadata == %{}
      assert section.template == :default
      assert section.slug == "some updated slug"
      assert section.content == "some updated content"
    end

    test "update_section/2 with invalid data returns error changeset" do
      section = section_fixture()
      assert {:error, %Ecto.Changeset{}} = Site.update_section(section, @invalid_attrs)
      assert section == Site.get_section!(section.id)
    end

    test "delete_section/1 deletes the section" do
      section = section_fixture()
      assert {:ok, %Section{}} = Site.delete_section(section)
      assert_raise Ecto.NoResultsError, fn -> Site.get_section!(section.id) end
    end

    test "change_section/1 returns a section changeset" do
      section = section_fixture()
      assert %Ecto.Changeset{} = Site.change_section(section)
    end
  end
end
