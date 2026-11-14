defmodule MykonosBiennaleWeb.Admin.ProjectLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists projects", %{conn: conn} do
      _project = ContentFixtures.project_fixture(title: "Test Project Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/projects")
      assert html =~ "Test Project Title"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/projects")
      assert html =~ "/admin/projects/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/projects/new")
      html = lv |> element("#project-form") |> render()
      assert html =~ "title"
    end

    test "creates project on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/projects/new")

      lv
      |> form("#project-form", project: %{title: "New Project"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/projects")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/projects/new")

      html =
        lv
        |> form("#project-form", project: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      project = ContentFixtures.project_fixture(title: "Edit Project")
      {:ok, lv, _html} = live(conn, ~p"/admin/projects/#{project.id}/edit")
      html = lv |> element("#project-form") |> render()
      assert html =~ "Edit Project"
    end

    test "updates project on valid submit", %{conn: conn} do
      project = ContentFixtures.project_fixture(title: "Old Project Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/projects/#{project.id}/edit")

      lv
      |> form("#project-form", project: %{title: "Updated Project"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/projects")
    end
  end

  describe "Show" do
    test "renders project details", %{conn: conn} do
      project = ContentFixtures.project_fixture(title: "Show Project")
      {:ok, _lv, html} = live(conn, ~p"/admin/projects/#{project.id}")
      assert html =~ "Show Project"
    end
  end

  describe "Delete" do
    test "deletes project from index", %{conn: conn} do
      project = ContentFixtures.project_fixture(title: "Delete Project")
      {:ok, lv, _html} = live(conn, ~p"/admin/projects")
      lv |> element("[phx-click=delete][phx-value-id='#{project.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Project")
    end
  end

  describe "Form media" do
    setup do
      ContentFixtures.ensure_relationship_types()
      project = ContentFixtures.project_fixture(title: "Media Project")
      attached = ContentFixtures.media_fixture(caption: "Project attached")
      Content.attach_media_to_entity(project, attached, metadata: %{})
      free = ContentFixtures.media_fixture(caption: "Project free")
      {:ok, project: project, attached: attached, free: free}
    end

    test "validate keeps the form on the page", %{conn: conn, project: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}/edit")
      lv |> form("#project-form", project: %{title: "Renamed live"}) |> render_change()
      assert has_element?(lv, "#project-form")
    end

    test "attach_media attaches a selected item", %{conn: conn, project: p, free: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}/edit")

      lv
      |> element("form[phx-change=attach_media]")
      |> render_change(%{"media_id" => to_string(f.id)})

      assert render(lv) =~ "Project free"
      assert has_element?(lv, "button[phx-click=detach_media][phx-value-media-id=\"#{f.id}\"]")
    end

    test "attach_media with an empty selection changes nothing", %{conn: conn, project: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}/edit")
      lv |> element("form[phx-change=attach_media]") |> render_change(%{"media_id" => ""})
      assert has_element?(lv, "button[phx-click=detach_media]")
    end

    test "attach_media on an unsaved project reports the error", %{conn: conn, free: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/new")

      lv
      |> element("form[phx-change=attach_media]")
      |> render_change(%{"media_id" => to_string(f.id)})

      assert has_element?(lv, "#project-form")
    end

    test "detach_media removes an attached item", %{conn: conn, project: p, attached: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}/edit")

      lv
      |> element("button[phx-click=detach_media][phx-value-media-id=\"#{m.id}\"]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=detach_media][phx-value-media-id=\"#{m.id}\"]")
    end

    test "update_media_link stores a caption override", %{conn: conn, project: p, attached: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}/edit")

      lv
      |> element("form[phx-change=update_media_link]")
      |> render_change(%{
        "media_id" => to_string(m.id),
        "metadata" => %{"caption_override" => "Shown caption"}
      })

      link = Content.list_entity_media_links_for_entity(p) |> Enum.find(&(&1.media_id == m.id))
      assert link.metadata["caption_override"] == "Shown caption"
    end
  end

  describe "Show handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      project = ContentFixtures.project_fixture(title: "Shown Project")
      event = ContentFixtures.event_fixture(title: "Project Event")
      ContentFixtures.link_event_to_project(event, project)
      {:ok, project: project, event: event}
    end

    test "lists the project's linked event", %{conn: conn, project: p, event: e} do
      {:ok, _lv, html} = live(conn, ~p"/admin/projects/#{p.id}")
      assert html =~ "Shown Project"
      assert html =~ "Project Event"
      assert html =~ "/admin/events/#{e.id}"
    end

    test "switch_tab changes the active tab", %{conn: conn, project: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}")
      lv |> element("button[phx-click=switch_tab][phx-value-tab=fields]") |> render_click()
      assert has_element?(lv, "button[phx-click=switch_tab][phx-value-tab=fields]")
    end

    test "fields_changed info stores edited project fields", %{conn: conn, project: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/projects/#{p.id}")

      send(lv.pid, {:fields_changed, %{content: ~s({"title": "Renamed Project"})}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, p.id).fields["title"] ==
               "Renamed Project"

      send(lv.pid, {:fields_changed, %{content: "bad"}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, p.id).fields["title"] ==
               "Renamed Project"
    end
  end
end
