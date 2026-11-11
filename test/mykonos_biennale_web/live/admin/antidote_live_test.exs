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
end
