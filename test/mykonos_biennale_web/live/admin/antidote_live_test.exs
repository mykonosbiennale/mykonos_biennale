defmodule MykonosBiennaleWeb.Admin.AntidoteLiveTest do
  use MykonosBiennaleWeb.AdminCase

  import Phoenix.LiveViewTest

  alias MykonosBiennale.Content

  setup do
    {:ok, biennale} = Content.create_biennale(%{year: 2025, theme: "Test"})

    project =
      MykonosBiennale.Repo.insert!(%MykonosBiennale.Content.Entity{
        id: 30,
        identity: "Treasure Hunt",
        type: "project",
        slug: "treasure-hunt-test",
        visible: true,
        fields: %{"title" => "Treasure Hunt"}
      })

    {:ok, event} =
      Content.create_event(%{
        title: "Treasure Hunt - Antidote",
        type: "exhibition",
        biennale_id: biennale.id
      })

    {:ok, decoy} =
      Content.create_event(%{
        title: "Opening Ceremony of Antidote Boxes",
        type: "performance",
        biennale_id: biennale.id
      })

    for e <- [event, decoy] do
      Content.create_relationship(%{
        slug: "event_project",
        label: "is_a",
        subject_id: e.id,
        object_id: project.id,
        fields: %{}
      })
    end

    %{event: event, biennale: biennale}
  end

  test "renders the form for an admin", %{conn: conn} do
    {:ok, lv, html} = live(conn, ~p"/admin/antidote")
    assert html =~ "Quick Antidote"
    assert html =~ "Treasure Hunt - Antidote"
    assert render(lv) =~ "Save artist and artwork"
  end

  test "saves a blank title as Untitled", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/antidote")

    html =
      render_submit(lv, "save", %{
        "artist" => %{"first_name" => "Chris", "last_name" => "Golub"},
        "artwork" => %{"title" => " "}
      })

    assert html =~ "Untitled"
  end

  test "saves the artwork then shows the review step", %{conn: conn} do
    {:ok, lv, _} = live(conn, ~p"/admin/antidote")

    html =
      render_submit(lv, "save", %{
        "artist" => %{"first_name" => "Chris", "last_name" => "Golub"},
        "artwork" => %{"title" => "Antidote"}
      })

    assert html =~ "Review"
    assert html =~ "Chris Golub"
    assert html =~ "Antidote"
  end

  describe "wizard steps" do
    test "select_year to a year with no Antidote event shows the error", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      html =
        lv
        |> element("form[phx-change=select_year]")
        |> render_change(%{"year" => "1999"})

      assert html =~ "No Antidote event for 1999"
    end

    test "search_artist shows matching participants", %{conn: conn} do
      ContentFixtures.participant_fixture(first_name: "Searchable", last_name: "Artist")
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      lv
      |> element("form[phx-change=search_artist]")
      |> render_change(%{"q" => "searchable"})

      assert has_element?(lv, "button[phx-click=pick_artist]")
    end

    test "search_artist with a one-letter query returns nothing", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      lv
      |> element("form[phx-change=search_artist]")
      |> render_change(%{"q" => "a"})

      refute has_element?(lv, "button[phx-click=pick_artist]")
    end

    test "pick_artist fills the artist fields from the participant", %{conn: conn} do
      p = ContentFixtures.participant_fixture(first_name: "Picked", last_name: "Person")
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      lv
      |> element("form[phx-change=search_artist]")
      |> render_change(%{"q" => "picked"})

      lv |> element("button[phx-click=pick_artist][phx-value-id=\"#{p.id}\"]") |> render_click()
      assert render(lv) =~ "Picked"
    end

    test "new_artist clears any picked artist", %{conn: conn} do
      p = ContentFixtures.participant_fixture(first_name: "Clear", last_name: "Me")
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      lv
      |> element("form[phx-change=search_artist]")
      |> render_change(%{"q" => "clear"})

      lv |> element("button[phx-click=pick_artist][phx-value-id=\"#{p.id}\"]") |> render_click()
      lv |> element("button[phx-click=new_artist]") |> render_click()
      assert has_element?(lv, "#antidote-form")
    end

    test "validate updates the artist and artwork fields", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      lv
      |> form("#antidote-form", artist: %{first_name: "Typed"}, artwork: %{title: "Typed Work"})
      |> render_change()

      assert render(lv) =~ "Typed Work"
    end

    test "cancel_upload removes a pending file", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      file =
        file_input(lv, "#antidote-form", :images, [
          %{
            name: "cancel.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "cancel.jpg", 10)
      lv |> element("button[phx-click=cancel_upload]") |> render_click()
      refute render(lv) =~ "cancel.jpg"
    end

    test "review step toggles media and adds it to the art board", %{conn: conn, event: event} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      file =
        file_input(lv, "#antidote-form", :images, [
          %{
            name: "board.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "board.jpg")

      render_submit(lv, "save", %{
        "artist" => %{"first_name" => "Board", "last_name" => "Tester"},
        "artwork" => %{"title" => "Board Work"}
      })

      assert has_element?(lv, "button[phx-click=toggle_media]")
      lv |> element("button[phx-click=toggle_media]") |> render_click()
      assert has_element?(lv, "button[phx-click=add_to_artboard]")
      lv |> element("button[phx-click=add_to_artboard]") |> render_click()

      # Success returns the wizard to the form step and saves the art board.
      assert has_element?(lv, "#antidote-form")

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, event.id).fields[
               "artboard_media_ids"
             ] != nil
    end

    test "new_work returns to the form step", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/antidote")

      render_submit(lv, "save", %{
        "artist" => %{"first_name" => "Again", "last_name" => "Artist"},
        "artwork" => %{"title" => "First Work"}
      })

      lv |> element("button[phx-click=new_work]") |> render_click()
      assert has_element?(lv, "#antidote-form")
    end
  end
end
