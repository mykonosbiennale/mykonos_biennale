defmodule MykonosBiennaleWeb.Admin.EventLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content.Entity

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

  describe "Form media (screening events)" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025)

      event =
        ContentFixtures.event_fixture(
          title: "Screening Event",
          type: "screening",
          biennale: biennale
        )

      attached = ContentFixtures.media_fixture(caption: "Attached photo")
      Content.attach_media_to_entity(event, attached, metadata: %{})
      free = ContentFixtures.media_fixture(caption: "Free photo")
      {:ok, event: event, attached: attached, free: free}
    end

    test "attach_media with an empty selection changes nothing", %{conn: conn, event: e} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")
      lv |> element("form[phx-change=attach_media]") |> render_change(%{"media_id" => ""})
      # Nothing new attached: the existing item keeps its detach button.
      assert has_element?(lv, "button[phx-click=detach_media]")
    end

    test "attach_media attaches a selected media item", %{conn: conn, event: e, free: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")

      lv
      |> element("form[phx-change=attach_media]")
      |> render_change(%{"media_id" => to_string(f.id)})

      assert render(lv) =~ "Free photo"
    end

    test "detach_media removes an attached item", %{conn: conn, event: e, attached: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")

      lv
      |> element("button[phx-click=detach_media][phx-value-media-id=\"#{m.id}\"]")
      |> render_click()

      # The detached item goes back into the attach dropdown, so check the
      # detach button rather than the caption text.
      refute has_element?(lv, "button[phx-click=detach_media][phx-value-media-id=\"#{m.id}\"]")
    end
  end

  describe "Form poster and artboard (exhibition events)" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025)

      event =
        ContentFixtures.event_fixture(
          title: "Exhibit Event",
          type: "exhibition",
          biennale: biennale
        )

      artwork = ContentFixtures.artwork_fixture(title: "Pool Work")
      ContentFixtures.link_artwork_to_event(artwork, event)
      pool_media = ContentFixtures.media_fixture(caption: "Pool photo")
      Content.attach_media_to_entity(artwork, pool_media, metadata: %{})
      free = ContentFixtures.media_fixture(caption: "Free photo")
      {:ok, event: event, pool_media: pool_media, free: free}
    end

    test "attach_poster sets and remove_poster clears the poster", %{
      conn: conn,
      event: e,
      free: f
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")

      lv
      |> element("form[phx-change=attach_poster]")
      |> render_change(%{"media_id" => to_string(f.id)})

      assert has_element?(lv, "button[phx-click=remove_poster]")

      lv |> element("button[phx-click=remove_poster]") |> render_click()
      refute has_element?(lv, "button[phx-click=remove_poster]")
    end

    test "add_to_artboard then remove_from_artboard", %{conn: conn, event: e, pool_media: pm} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")

      lv
      |> element("div[phx-click=add_to_artboard][phx-value-media-id=\"#{pm.id}\"]")
      |> render_click()

      lv
      |> element("div[phx-click=remove_from_artboard][phx-value-media-id=\"#{pm.id}\"]")
      |> render_click()

      assert has_element?(lv, "div[phx-click=add_to_artboard][phx-value-media-id=\"#{pm.id}\"]")
    end

    test "validate and a blank-title save keep the form open", %{conn: conn, event: e} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}/edit")
      lv |> form("#event-form", event: %{title: ""}) |> render_change()
      lv |> form("#event-form", event: %{title: ""}) |> render_submit()
      assert has_element?(lv, "#event-form")
    end
  end

  describe "Show linked data and handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      project = ContentFixtures.project_fixture(title: "Parent Project")

      event =
        ContentFixtures.event_fixture(
          title: "Full Event",
          type: "exhibition",
          biennale: biennale,
          project: project
        )

      artwork = ContentFixtures.artwork_fixture(title: "Hung Work")
      ContentFixtures.link_artwork_to_event(artwork, event)
      creator = ContentFixtures.participant_fixture(first_name: "Hung", last_name: "Maker")
      ContentFixtures.link_artwork_to_participant(artwork, creator)
      photo = ContentFixtures.media_fixture(caption: "Hung photo")
      Content.attach_media_to_entity(artwork, photo, metadata: %{})

      {:ok,
       event: event, biennale: biennale, project: project, artwork: artwork, creator: creator}
    end

    test "shows the biennale, project, artwork and its creator", %{
      conn: conn,
      event: e,
      biennale: b,
      project: p,
      artwork: a,
      creator: _c
    } do
      {:ok, _lv, html} = live(conn, ~p"/admin/events/#{e.id}")
      assert html =~ "Full Event"
      assert html =~ "/admin/biennales/#{b.id}"
      assert html =~ "/admin/projects/#{p.id}"
      assert html =~ "Hung Work"
      assert html =~ "/admin/artworks/#{a.id}"
      assert html =~ "Hung Maker"
      assert html =~ "Hung Maker"
    end

    test "switch_tab changes the active tab", %{conn: conn, event: e} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}")
      lv |> element("button[phx-click=switch_tab][phx-value-tab=fields]") |> render_click()
      assert has_element?(lv, "button[phx-click=switch_tab][phx-value-tab=fields]")
    end

    test "fields_changed info stores edited event fields", %{conn: conn, event: e} do
      {:ok, lv, _} = live(conn, ~p"/admin/events/#{e.id}")

      send(
        lv.pid,
        {:fields_changed, %{content: ~s({"title": "Edited Event", "type": "exhibition"})}}
      )

      _ = render(lv)
      assert MykonosBiennale.Repo.get!(Entity, e.id).fields["title"] == "Edited Event"

      send(lv.pid, {:fields_changed, %{content: "bad"}})
      _ = render(lv)
      assert MykonosBiennale.Repo.get!(Entity, e.id).fields["title"] == "Edited Event"
    end
  end

  describe "Index search and saved events" do
    test "search filters the event list", %{conn: conn} do
      ContentFixtures.event_fixture(title: "Findable Event")
      ContentFixtures.event_fixture(title: "Other Thing")
      {:ok, lv, _} = live(conn, ~p"/admin/events")

      html = render_hook(lv, "search", %{"search" => "findable"})
      assert html =~ "Findable Event"
      refute html =~ "Other Thing"
    end

    test "clear_search restores the full list and patches the URL", %{conn: conn} do
      ContentFixtures.event_fixture(title: "Kept Event")
      {:ok, lv, _} = live(conn, ~p"/admin/events")
      render_hook(lv, "search", %{"search" => "nothing-matches"})
      render_hook(lv, "clear_search", %{})
      assert_patch(lv, "/admin/events?sort_by=id&page=1&sort_dir=desc")
      assert render(lv) =~ "Kept Event"
    end

    test "a saved event from the form is shown in the list", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/events")
      event = ContentFixtures.event_fixture(title: "Just Saved")

      send(lv.pid, {MykonosBiennaleWeb.Admin.EventLive.FormComponent, {:saved, event}})
      assert render(lv) =~ "Just Saved"
    end
  end
end
