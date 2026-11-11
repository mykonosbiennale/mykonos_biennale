defmodule MykonosBiennaleWeb.Admin.MediaPhotographerTest do
  use MykonosBiennaleWeb.AdminCase

  import Phoenix.LiveViewTest

  alias MykonosBiennale.{Content, MediaCredit}

  test "picks a photographer on the edit form and saves it", %{conn: conn} do
    {:ok, thanos} =
      Content.create_participant(%{name: "Thanos", first_name: "", last_name: "Thanos"})

    {:ok, media} =
      Content.create_media(%{
        caption: "Work",
        source_type: "url",
        source_url: "https://example.com/a.jpg",
        mime_type: "image/jpeg"
      })

    {:ok, lv, _} = live(conn, ~p"/admin/media/#{media.id}/edit")

    lv |> element("form[phx-change=search_photographer]") |> render_change(%{"q" => "Thanos"})

    lv
    |> element("button[phx-click=pick_photographer][phx-value-id='#{thanos.id}']")
    |> render_click()

    assert render(lv) =~ "Thanos"

    lv |> form("#media-form", media: %{caption: "Work"}) |> render_submit()

    assert MediaCredit.photographer_id(Content.get_media!(media.id)) == thanos.id
  end
end
