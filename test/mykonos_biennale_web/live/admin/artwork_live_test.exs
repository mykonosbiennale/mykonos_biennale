defmodule MykonosBiennaleWeb.Admin.ArtworkLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists artworks", %{conn: conn} do
      _artwork = ContentFixtures.artwork_fixture(title: "Test Artwork Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks")
      assert html =~ "Test Artwork Title"
    end

    test "has + New and Merge links", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks")
      assert html =~ "/admin/artworks/new"
      assert html =~ "/admin/artworks/merge"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")
      html = lv |> element("#artwork-form") |> render()
      assert html =~ "title"
    end

    test "creates artwork on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")

      lv
      |> form("#artwork-form", artwork: %{title: "New Artwork"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/artworks")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/new")

      html =
        lv
        |> form("#artwork-form", artwork: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Edit Artwork")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/#{artwork.id}/edit")
      html = lv |> element("#artwork-form") |> render()
      assert html =~ "Edit Artwork"
    end

    test "updates artwork on valid submit", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Old Artwork Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks/#{artwork.id}/edit")

      lv
      |> form("#artwork-form", artwork: %{title: "Updated Artwork"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/artworks")
    end
  end

  describe "Show" do
    test "renders artwork details", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Show Artwork")
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/#{artwork.id}")
      assert html =~ "Show Artwork"
    end
  end

  describe "Delete" do
    test "deletes artwork from index", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Delete Artwork")
      {:ok, lv, _html} = live(conn, ~p"/admin/artworks")
      lv |> element("[phx-click=delete][phx-value-id='#{artwork.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Artwork")
    end
  end

  describe "Merge" do
    test "mounts merge page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/merge")
      assert html =~ "Merge Duplicate Artworks"
    end
  end

  describe "Reimport Preview" do
    setup do
      dir = Path.join(File.cwd!(), "exports/festival")
      File.mkdir_p!(dir)
      path = Path.join(dir, "records.json")
      File.write!(path, Jason.encode!([]))
      on_exit(fn -> File.rm(path) end)
      :ok
    end

    test "mounts reimport preview page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/import_preview")
      assert html =~ "Artwork Reimport Preview"
    end
  end

  describe "Show handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      artwork = ContentFixtures.artwork_fixture(title: "Main Work")
      other = ContentFixtures.artwork_fixture(title: "Other Work")
      media = ContentFixtures.media_fixture(caption: "Work photo")
      Content.attach_media_to_entity(artwork, media, metadata: %{})
      {:ok, artwork: artwork, other: other, media: media}
    end

    test "switch_tab changes the active tab", %{conn: conn, artwork: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")
      assert render_hook(lv, "switch_tab", %{"tab" => "metadata"}) =~ "Main Work"
    end

    test "start and cancel moving media", %{conn: conn, artwork: a, media: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")
      render_hook(lv, "start_move_media", %{"media-id" => to_string(m.id)})
      render_hook(lv, "cancel_move_media", %{})
      assert render(lv) =~ "Main Work"
    end

    test "search_artwork finds other artworks and ignores blank searches", %{
      conn: conn,
      artwork: a,
      media: m
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")
      render_hook(lv, "start_move_media", %{"media-id" => to_string(m.id)})

      html = render_hook(lv, "search_artwork", %{"search" => "other"})
      assert html =~ "Other Work"

      render_hook(lv, "search_artwork", %{"search" => "  "})
      refute render(lv) =~ "phx-value-target-id"
    end

    test "move_media moves a photo to another artwork", %{
      conn: conn,
      artwork: a,
      other: o,
      media: m
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")
      render_hook(lv, "start_move_media", %{"media-id" => to_string(m.id)})

      html = render_hook(lv, "move_media", %{"target-id" => to_string(o.id)})
      assert html =~ "Media moved to"
    end

    test "remove_media detaches the photo", %{conn: conn, artwork: a, media: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")
      assert render_hook(lv, "remove_media", %{"media-id" => to_string(m.id)}) =~ "Media removed"
    end

    test "rotate_media queues a rotation", %{conn: conn, artwork: a, media: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")

      assert render_hook(lv, "rotate_media", %{"media-id" => to_string(m.id), "degrees" => "270"}) =~
               "Rotation 270"
    end

    test "fields_changed info stores the edited fields", %{conn: conn, artwork: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}")

      send(lv.pid, {:fields_changed, %{content: ~s({"title": "Edited Title"})}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, a.id).fields["title"] ==
               "Edited Title"

      send(lv.pid, {:fields_changed, %{content: "nope"}})
      assert render(lv) =~ "Edited Title"
    end
  end

  describe "Merge duplicates" do
    setup do
      ContentFixtures.ensure_relationship_types()
      event = ContentFixtures.event_fixture(title: "Dup Event")
      participant = ContentFixtures.participant_fixture(first_name: "Dup", last_name: "Artist")
      a = ContentFixtures.artwork_fixture(title: "Same Title")
      b = ContentFixtures.artwork_fixture(title: "Same Title")

      for art <- [a, b] do
        ContentFixtures.link_artwork_to_event(art, event)
        ContentFixtures.link_artwork_to_participant(art, participant)
      end

      {:ok, a: a, b: b}
    end

    test "lists the duplicate group", %{conn: conn, a: a, b: b} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/merge")
      assert html =~ "Same Title"
      assert html =~ ~s(phx-value-id="#{a.id}")
      assert html =~ ~s(phx-value-id="#{b.id}")
    end

    test "switching to broad mode patches the URL", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/merge")
      render_hook(lv, "set_group_mode", %{"mode" => "broad"})
      assert_patch(lv, "/admin/artworks/merge?page=1")
    end

    test "toggle_select selects and deselects an artwork", %{conn: conn, a: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/merge")
      render_hook(lv, "toggle_select", %{"id" => to_string(a.id)})
      render_hook(lv, "toggle_select", %{"id" => to_string(a.id)})
      assert render(lv) =~ "Same Title"
    end

    test "merge_selected merges the selected duplicates", %{conn: conn, a: a, b: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/merge")
      render_hook(lv, "toggle_select", %{"id" => to_string(a.id)})
      render_hook(lv, "toggle_select", %{"id" => to_string(b.id)})
      render_hook(lv, "merge_selected", %{})
      assert_patch(lv, "/admin/artworks/merge?page=1")
    end

    test "merge_all merges every duplicate group", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/merge")
      render_hook(lv, "merge_all", %{})
      assert_patch(lv, "/admin/artworks/merge?page=1")
    end

    test "an out-of-range page is clamped", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/merge?page=99")
      assert is_binary(html)
    end
  end

  describe "Form linking events and participants" do
    setup do
      ContentFixtures.ensure_relationship_types()
      event = ContentFixtures.event_fixture(title: "Linked Show", type: "exhibition")
      other_event = ContentFixtures.event_fixture(title: "Spare Show", type: "exhibition")
      participant = ContentFixtures.participant_fixture(first_name: "Maker", last_name: "Person")
      artwork = ContentFixtures.artwork_fixture(title: "Form Work")
      ContentFixtures.link_artwork_to_event(artwork, event)
      {:ok, artwork: artwork, event: event, other_event: other_event, participant: participant}
    end

    test "attach_event with an empty selection changes nothing", %{conn: conn, artwork: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}/edit")
      lv |> element("form[phx-change=attach_event]") |> render_change(%{"event_id" => ""})
      assert has_element?(lv, "#artwork-form")
    end

    test "attach_event links a new event", %{conn: conn, artwork: a, other_event: o} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}/edit")

      lv
      |> element("form[phx-change=attach_event]")
      |> render_change(%{"event_id" => to_string(o.id)})

      assert Content.list_artwork_linked_events(a) |> Enum.any?(&(&1.object_id == o.id))
    end

    test "detach_event unlinks an event", %{conn: conn, artwork: a, event: e} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}/edit")

      lv
      |> element("button[phx-click=detach_event][phx-value-event-id=\"#{e.id}\"]")
      |> render_click()

      refute Enum.any?(Content.list_artwork_linked_events(a), &(&1.object_id == e.id))
    end

    test "link_participant with a role links the chosen person", %{
      conn: conn,
      artwork: a,
      participant: p
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}/edit")

      lv
      |> element("input[phx-change=set_participant_role]")
      |> render_change(%{"role" => "artist"})

      lv
      |> element("form[phx-change=search_participant_to_link]")
      |> render_change(%{"search" => "maker"})

      lv
      |> element("button[phx-click=link_participant][phx-value-participant-id=\"#{p.id}\"]")
      |> render_click()

      assert Enum.any?(Content.list_artwork_linked_participants(a), &(&1.object_id == p.id))
    end

    test "detach_participant unlinks a linked participant", %{
      conn: conn,
      artwork: a,
      participant: p
    } do
      {:ok, _} = Content.attach_participant_to_artwork(a, p, "artist")
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/#{a.id}/edit")

      lv
      |> element("button[phx-click=detach_participant][phx-value-participant-id=\"#{p.id}\"]")
      |> render_click()

      refute Enum.any?(Content.list_artwork_linked_participants(a), &(&1.object_id == p.id))
    end
  end

  describe "Reimport preview handlers" do
    test "shows the empty state when there is no export file", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/import_preview")
      assert is_binary(html)
      refute html =~ "Import complete"
      assert html =~ "Reimport"
    end

    test "do_import with nothing to import reports completion", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/artworks/import_preview")
      html = render_hook(lv, "do_import", %{})
      assert html =~ "Import complete"
      assert html =~ "0 errors"
    end
  end

  describe "Reimport preview with records" do
    setup do
      dir = Path.join(System.tmp_dir!(), "reimport_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      path = Path.join(dir, "records.json")

      art = fn pk ->
        %{
          "model" => "festival.art",
          "pk" => pk,
          "fields" => %{"title" => "Piece", "leader" => pk == 1},
          "foreign_keys" => %{
            "project" => %{"pk" => 10},
            "project_x" => %{"pk" => 20},
            "artist" => %{"pk" => 30}
          },
          "files" => [%{"path" => "old/a.jpg"}]
        }
      end

      records = [
        art.(1),
        art.(2),
        %{
          "model" => "festival.project",
          "pk" => 10,
          "fields" => %{"slug" => "proj"},
          "foreign_keys" => %{"festival" => %{"pk" => 40}}
        },
        %{
          "model" => "festival.projectseason",
          "pk" => 20,
          "foreign_keys" => %{"festival" => %{"pk" => 40}}
        },
        %{"model" => "festival.artist", "pk" => 30, "fields" => %{"name" => "Artist A"}},
        %{
          "model" => "festival.festival",
          "pk" => 40,
          "fields" => %{"year" => 2024, "title" => "Fest 2024"}
        }
      ]

      File.write!(path, Jason.encode!(records))
      Application.put_env(:mykonos_biennale, :reimport_records_path, path)

      on_exit(fn ->
        Application.delete_env(:mykonos_biennale, :reimport_records_path)
        File.rm_rf!(dir)
      end)

      media =
        ContentFixtures.media_fixture(caption: "Matched photo")
        |> Ecto.Changeset.change(original_name: "mykonos-biennale-a.jpg")
        |> MykonosBiennale.Repo.update!()

      {:ok, media: media}
    end

    test "groups duplicate records and reports matched media", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/import_preview")
      assert html =~ "Piece"
      assert html =~ "Artist A"
    end

    test "a page number past the end is clamped", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/artworks/import_preview?page=99")
      assert html =~ "Piece"
    end
  end
end
