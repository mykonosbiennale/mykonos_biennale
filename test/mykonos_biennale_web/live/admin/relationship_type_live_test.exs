defmodule MykonosBiennaleWeb.Admin.RelationshipTypeLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists relationship types", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/relationship_types")
      assert html =~ "Label"
      assert html =~ "Slug"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/relationship_types")
      assert html =~ "/admin/relationship_types/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/relationship_types/new")
      html = lv |> element("#relationship-type-form") |> render()
      assert html =~ "label"
      assert html =~ "slug"
    end

    test "creates relationship type on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/relationship_types/new")

      lv
      |> form("#relationship-type-form",
        relationship_type: %{label: "Test Label", slug: "test-label-#{System.unique_integer()}"}
      )
      |> render_submit()

      assert_patch(lv, ~p"/admin/relationship_types")
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      ContentFixtures.ensure_relationship_types()
      {:ok, lv, _html} = live(conn, ~p"/admin/relationship_types/1/edit")
      html = lv |> element("#relationship-type-form") |> render()
      assert html =~ "label"
    end
  end

  describe "Delete" do
    test "deletes relationship type from index", %{conn: conn} do
      ContentFixtures.ensure_relationship_types()
      {:ok, lv, _html} = live(conn, ~p"/admin/relationship_types")
      lv |> element("[phx-click=delete][phx-value-id='1']") |> render_click()
      refute has_element?(lv, "tr#relationship_types-1")
    end
  end
end
