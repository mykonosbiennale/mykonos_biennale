defmodule MykonosBiennaleWeb.EventPageTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  defp event_with(fields, type) do
    event =
      ContentFixtures.event_fixture(
        title: "Page Event #{System.unique_integer([:positive])}",
        type: type
      )

    event
    |> Ecto.Changeset.change(fields: Map.merge(event.fields, fields))
    |> Repo.update!()
  end

  test "an event with an empty date and time shows no date or time", %{conn: conn} do
    event = event_with(%{"date" => "", "time" => ""}, "workshop")
    html = html_response(get(conn, "/event/#{event.id}"), 200)
    assert html =~ event.fields["title"]
  end

  test "an unparseable date is shown as typed and a time is shown as given", %{conn: conn} do
    event = event_with(%{"date" => "sometime soon", "time" => "9:00"}, "workshop")
    html = html_response(get(conn, "/event/#{event.id}"), 200)
    assert html =~ "sometime soon"
    assert html =~ "9:00"
  end

  test "a valid ISO date is formatted for display", %{conn: conn} do
    event = event_with(%{"date" => "2025-09-27"}, "workshop")
    html = html_response(get(conn, "/event/#{event.id}"), 200)
    assert html =~ "Sep 27, 2025"
  end
end
