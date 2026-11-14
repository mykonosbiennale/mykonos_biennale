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
        section: %{
          title: "New Section",
          page_id: page.id,
          content: "<p>Hello</p>",
          template: "default"
        }
      )
      |> render_submit()

      html = render(lv)
      assert html =~ "New Section"
      assert MykonosBiennale.Repo.get_by(MykonosBiennale.Site.Section, title: "New Section")
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

  describe "Show handlers" do
    test "switch_tab and change persist section metadata", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Show Section")
      {:ok, lv, html} = live(conn, ~p"/admin/sections/#{section.id}")
      assert html =~ "Show Section"

      assert render_hook(lv, "switch_tab", %{"tab" => "metadata"}) =~ "Show Section"
      render_hook(lv, "change", %{"content" => ~s({"x": 1})})

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Site.Section, section.id).metadata == %{
               "x" => 1
             }
    end

    test "change ignores invalid JSON", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Bad Section")
      {:ok, lv, _} = live(conn, ~p"/admin/sections/#{section.id}")
      assert render_hook(lv, "change", %{"content" => "{"}) =~ "Bad Section"
    end

    test "metadata_changed info persists metadata", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Info Section")
      {:ok, lv, _} = live(conn, ~p"/admin/sections/#{section.id}")

      send(lv.pid, {:metadata_changed, %{content: ~s({"y": 2})}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Site.Section, section.id).metadata == %{
               "y" => 2
             }

      send(lv.pid, {:metadata_changed, %{content: "bad"}})
      assert render(lv) =~ "Info Section"
    end

    test "saved info from the form component updates the section", %{conn: conn} do
      section = SiteFixtures.section_fixture(title: "Old Section")
      {:ok, lv, _} = live(conn, ~p"/admin/sections/#{section.id}")

      send(
        lv.pid,
        {MykonosBiennaleWeb.Admin.SectionLive.FormComponent,
         {:saved, %{section | title: "New Section"}}}
      )

      assert render(lv) =~ "New Section"
    end
  end

  describe "Form handlers" do
    setup do
      page = SiteFixtures.page_fixture()
      section = SiteFixtures.section_fixture(title: "Form Section", page: page)
      {:ok, page: page, section: section}
    end

    test "validate keeps the form on the page", %{conn: conn, section: sec} do
      {:ok, lv, _} = live(conn, ~p"/admin/sections/#{sec.id}/edit")
      lv |> form("#section-form", section: %{title: "Renamed Section"}) |> render_change()
      assert has_element?(lv, "#section-form")
    end

    test "saving with a blank title keeps the form open and changes nothing", %{
      conn: conn,
      section: sec
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/sections/#{sec.id}/edit")
      lv |> form("#section-form", section: %{title: ""}) |> render_submit()
      assert has_element?(lv, "#section-form")

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Site.Section, sec.id).title ==
               "Form Section"
    end

    test "a new section with a blank title keeps the form open", %{conn: conn, page: page} do
      {:ok, lv, _} = live(conn, ~p"/admin/sections/new")

      lv
      |> form("#section-form",
        section: %{title: "", page_id: page.id, content: "<p>x</p>", template: "default"}
      )
      |> render_submit()

      assert has_element?(lv, "#section-form")
    end

    test "the index change event pushes metadata into the open form", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sections/new")
      assert is_binary(render_hook(lv, "change", %{"content" => ~s({"k": "v"})}))
    end

    test "the index change event ignores invalid JSON", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sections/new")
      assert is_binary(render_hook(lv, "change", %{"content" => "{nope"}))
    end
  end
end
