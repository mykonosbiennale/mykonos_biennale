defmodule MykonosBiennaleWeb.Admin.EventLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists events", %{conn: conn} do
      _event = ContentFixtures.event_fixture(title: "Test Event Show", type: "exhibition")
      {:ok, _lv, html} = live(conn, ~p"/admin/events")
      assert html =~ "Test Event Show"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/events")
      assert html =~ "/admin/events/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/events/new")
      html = lv |> element("#event-form") |> render()
      assert html =~ "title"
      assert html =~ "type"
    end

    test "creates event on valid submit", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      {:ok, lv, _html} = live(conn, ~p"/admin/events/new")

      lv
      |> form("#event-form",
        event: %{title: "New Event", type: "exhibition", biennale_id: biennale.id}
      )
      |> render_submit()

      assert_patch(lv, ~p"/admin/events")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/events/new")

      html =
        lv
        |> form("#event-form", event: %{title: "", type: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Edit Event", type: "screening")
      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")
      html = lv |> element("#event-form") |> render()
      assert html =~ "Edit Event"
    end

    test "updates event on valid submit", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Old Title", type: "exhibition")
      {:ok, lv, _html} = live(conn, ~p"/admin/events/#{event.id}/edit")

      lv
      |> form("#event-form", event: %{title: "Updated Title"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/events")
    end
  end

  describe "Show" do
    test "renders event details", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Show Event", type: "exhibition")
      {:ok, _lv, html} = live(conn, ~p"/admin/events/#{event.id}")
      assert html =~ "Show Event"
    end
  end

  describe "Delete" do
    test "deletes event from index", %{conn: conn} do
      event = ContentFixtures.event_fixture(title: "Delete Event", type: "exhibition")
      {:ok, lv, _html} = live(conn, ~p"/admin/events")
      lv |> element("[phx-click=delete][phx-value-id='#{event.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Event")
    end
  end
end
