defmodule MykonosBiennaleWeb.Admin.ParticipantLiveTest do
  use MykonosBiennaleWeb.AdminCase

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  describe "Index" do
    test "lists participants", %{conn: conn} do
      _participant = ContentFixtures.participant_fixture(first_name: "John", last_name: "Doe")
      {:ok, _lv, html} = live(conn, ~p"/admin/participants")
      assert html =~ "John Doe"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/participants")
      assert html =~ "/admin/participants/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/new")
      html = lv |> element("#participant-form") |> render()
      assert html =~ "first_name"
      assert html =~ "last_name"
    end

    test "creates participant on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/new")

      lv
      |> form("#participant-form", participant: %{first_name: "New", last_name: "Artist"})
      |> render_submit()

      html = render(lv)
      assert html =~ "New Artist"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Edit", last_name: "Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/#{participant.id}/edit")
      html = lv |> element("#participant-form") |> render()
      assert html =~ "Edit"
    end

    test "updates participant on valid submit", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Old", last_name: "Name")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/#{participant.id}/edit")

      lv
      |> form("#participant-form", participant: %{first_name: "Updated"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/participants")
    end
  end

  describe "Show" do
    test "renders participant details", %{conn: conn} do
      participant =
        ContentFixtures.participant_fixture(first_name: "Show", last_name: "Participant")

      {:ok, _lv, html} = live(conn, ~p"/admin/participants/#{participant.id}")
      assert html =~ "Show Participant"
    end
  end

  describe "Delete" do
    test "deletes participant from index", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Delete", last_name: "Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants")
      lv |> element("[phx-click=delete][phx-value-id='#{participant.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Me")
    end
  end
end
