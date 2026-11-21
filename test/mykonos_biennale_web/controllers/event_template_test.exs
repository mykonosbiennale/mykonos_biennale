defmodule MykonosBiennaleWeb.EventTemplateTest do
  use MykonosBiennaleWeb.ConnCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.ContentFixtures

  setup do
    biennale = ContentFixtures.biennale_fixture(year: 2025)
    {:ok, biennale: biennale}
  end

  defp event(biennale, attrs) do
    {:ok, event} =
      Content.create_event(
        Map.merge(%{title: "Template Event", biennale_id: biennale.id}, Map.new(attrs))
      )

    event
  end

  test "a chosen mosaic template renders the packed grid", %{conn: conn, biennale: biennale} do
    event = event(biennale, type: "exhibition", template: "mosaic")
    {:ok, _} = Content.attach_media_to_entity(event, ContentFixtures.media_fixture())

    html = html_response(get(conn, "/event/#{event.id}"), 200)

    assert html =~ ~s(class="mosaic")
    refute html =~ "w-full md:w-5/6"
  end

  test "an empty template choice follows the event type", %{conn: conn, biennale: biennale} do
    event = event(biennale, type: "event", template: "")

    html = html_response(get(conn, "/event/#{event.id}"), 200)

    refute html =~ ~s(class="mosaic")
  end

  test "each layout route renders its own template, whatever the event stores", %{
    conn: conn,
    biennale: biennale
  } do
    event = event(biennale, type: "event", template: "default")
    {:ok, _} = Content.attach_media_to_entity(event, ContentFixtures.media_fixture())

    mosaic = html_response(get(conn, "/event/#{event.id}/layout/mosaic"), 200)
    assert mosaic =~ ~s(class="mosaic")

    standard = html_response(get(conn, "/event/#{event.id}/layout/default"), 200)
    refute standard =~ ~s(class="mosaic")
  end

  test "an unknown layout is a 404", %{conn: conn, biennale: biennale} do
    event = event(biennale, type: "event", template: "")

    assert html_response(get(conn, "/event/#{event.id}/layout/nope"), 404)
  end

  test "the template choice is stored on the event", %{biennale: biennale} do
    event = event(biennale, type: "event", template: "mosaic")

    assert Content.get_event!(event.id).fields["template"] == "mosaic"

    {:ok, updated} = Content.update_event(event, %{template: ""})
    assert updated.fields["template"] == ""
  end
end
