defmodule MykonosBiennaleWeb.Admin.EventLive.QuickTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content
  alias MykonosBiennale.ContentFixtures

  setup do
    biennale = ContentFixtures.biennale_fixture(year: 2025)
    {:ok, biennale: biennale}
  end

  defp created_event(title) do
    Content.list_events()
    |> Enum.find(&(&1.fields["title"] == title))
  end

  test "creating an art show stores the exhibition type and moves to the art board step",
       %{conn: conn, biennale: biennale} do
    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/new")

    lv
    |> form("#quick-event-form",
      quick: %{
        category: "art_show",
        title: "Quick Art Show",
        biennale_id: to_string(biennale.id)
      }
    )
    |> render_submit()

    event = created_event("Quick Art Show")
    assert event.fields["type"] == "exhibition"
    assert_patch(lv, ~p"/admin/events/quick/#{event.id}")
    assert render(lv) =~ "Art board"
  end

  test "an event category stores the chosen kind of event", %{conn: conn, biennale: biennale} do
    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/new")

    # The kind-of-event select only appears once the category is Event.
    lv |> form("#quick-event-form", quick: %{category: "event"}) |> render_change()

    lv
    |> form("#quick-event-form",
      quick: %{
        category: "event",
        type: "workshop",
        title: "Quick Workshop",
        biennale_id: to_string(biennale.id)
      }
    )
    |> render_submit()

    assert created_event("Quick Workshop").fields["type"] == "workshop"
  end

  test "an existing event can be chosen to add media to", %{conn: conn, biennale: biennale} do
    {:ok, event} =
      Content.create_event(%{
        title: "Existing Show",
        type: "exhibition",
        biennale_id: biennale.id
      })

    {:ok, lv, html} = live(conn, ~p"/admin/events/quick/new")
    assert html =~ "Existing Show"

    lv
    |> form("#open-existing-form", event_id: to_string(event.id))
    |> render_submit()

    assert_patch(lv, ~p"/admin/events/quick/#{event.id}")
  end

  test "uploaded images become media on the event and join the art board", %{
    conn: conn,
    biennale: biennale
  } do
    {:ok, event} =
      Content.create_event(%{title: "Upload Show", type: "exhibition", biennale_id: biennale.id})

    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/#{event.id}")

    file =
      file_input(lv, "#quick-upload-form", :media, [
        %{
          name: "first.jpg",
          content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
          type: "image/jpeg"
        }
      ])

    render_upload(file, "first.jpg")

    [media] = Content.list_media_for_entity(event)
    assert media.original_name == "first.jpg"
    assert Content.get_event!(event.id).fields["artboard_media_ids"] == [media.id]
    refute render(lv) =~ "first.jpg"
  end

  test "a blank title is rejected", %{conn: conn, biennale: biennale} do
    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/new")

    html =
      lv
      |> form("#quick-event-form",
        quick: %{category: "art_show", title: "  ", biennale_id: to_string(biennale.id)}
      )
      |> render_submit()

    assert html =~ "Enter a title"
    assert created_event("  ") == nil
  end

  test "media attached to a screening is captioned on the media and shared", %{
    conn: conn,
    biennale: biennale
  } do
    {:ok, event} =
      Content.create_event(%{
        title: "Quick Screening",
        type: "screening",
        biennale_id: biennale.id
      })

    media = ContentFixtures.media_fixture()

    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/#{event.id}")

    render_hook(lv, "attach_media", %{"media_id" => to_string(media.id)})
    assert Enum.map(Content.list_media_for_entity(event), & &1.id) == [media.id]

    render_hook(lv, "save_grid", %{
      "nav" => "stay",
      "captions" => %{to_string(media.id) => "Opening night"}
    })

    assert Content.get_media!(media.id).caption == "Opening night"
  end

  test "the media grid removes checked rows from the event and keeps the rest", %{
    conn: conn,
    biennale: biennale
  } do
    {:ok, event} =
      Content.create_event(%{title: "Grid Event", type: "screening", biennale_id: biennale.id})

    keep = ContentFixtures.media_fixture()
    drop = ContentFixtures.media_fixture()
    {:ok, _} = Content.attach_media_to_entity(event, keep)
    {:ok, _} = Content.attach_media_to_entity(event, drop)

    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/#{event.id}")

    render_hook(lv, "save_grid", %{
      "nav" => "stay",
      "delete" => %{to_string(drop.id) => "true"}
    })

    assert Enum.map(Content.list_media_for_entity(event), & &1.id) == [keep.id]
    assert Content.get_media!(drop.id)
  end

  test "next and previous save the current page and move between pages", %{
    conn: conn,
    biennale: biennale
  } do
    {:ok, event} =
      Content.create_event(%{title: "Big Event", type: "screening", biennale_id: biennale.id})

    media = for _ <- 1..201, do: ContentFixtures.media_fixture()
    Enum.each(media, &Content.attach_media_to_entity(event, &1))

    {:ok, lv, html} = live(conn, ~p"/admin/events/quick/#{event.id}")
    assert html =~ "Page 1 of 2 · 201 items"

    first = hd(media)

    render_hook(lv, "save_grid", %{
      "nav" => "next",
      "captions" => %{to_string(first.id) => "Saved on next"}
    })

    assert_patched(lv, ~p"/admin/events/quick/#{event.id}?page=2")
    assert Content.get_media!(first.id).caption == "Saved on next"
    assert render(lv) =~ "Page 2 of 2"

    render_hook(lv, "save_grid", %{"nav" => "prev"})

    assert_patched(lv, ~p"/admin/events/quick/#{event.id}?page=1")
  end

  test "toggling an artwork on the art board stores its media id", %{
    conn: conn,
    biennale: biennale
  } do
    {:ok, event} =
      Content.create_event(%{title: "Quick Show", type: "exhibition", biennale_id: biennale.id})

    media = ContentFixtures.media_fixture()

    {:ok, lv, _html} = live(conn, ~p"/admin/events/quick/#{event.id}")
    render_hook(lv, "toggle_artboard", %{"media-id" => to_string(media.id)})

    assert Content.get_event!(event.id).fields["artboard_media_ids"] == [media.id]
  end
end
