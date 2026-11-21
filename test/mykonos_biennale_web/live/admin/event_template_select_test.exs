defmodule MykonosBiennaleWeb.Admin.EventTemplateSelectTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content
  alias MykonosBiennale.ContentFixtures

  setup %{conn: conn} do
    biennale = ContentFixtures.biennale_fixture(year: 2025)

    {:ok, event} =
      Content.create_event(%{title: "Picked Template", type: "event", biennale_id: biennale.id})

    {:ok, lv, html} = live(conn, ~p"/admin/events/#{event.id}/edit")
    {:ok, event: event, lv: lv, html: html}
  end

  test "the edit form offers the page templates", %{html: html} do
    assert html =~ "Page template"
    assert html =~ ~s(value="mosaic")
  end

  test "choosing the mosaic template stores it on the event", %{lv: lv, event: event} do
    lv
    |> form("#event-form", event: %{template: "mosaic"})
    |> render_submit()

    assert Content.get_event!(event.id).fields["template"] == "mosaic"
  end
end
