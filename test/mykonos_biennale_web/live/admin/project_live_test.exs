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
end
