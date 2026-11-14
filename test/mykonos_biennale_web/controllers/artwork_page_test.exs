defmodule MykonosBiennaleWeb.ArtworkPageTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  defp set_fields(entity, fields) do
    entity |> Ecto.Changeset.change(fields: fields) |> Repo.update!()
  end

  test "shows date, medium and size when they are set", %{conn: conn} do
    art =
      ContentFixtures.artwork_fixture(title: "Detailed Work")
      |> set_fields(%{
        "title" => "Detailed Work",
        "date" => "2024",
        "medium" => "Oil",
        "size" => "60x40"
      })

    html = html_response(get(conn, "/art/#{art.id}"), 200)
    assert html =~ "Detailed Work"
    assert html =~ "2024"
    assert html =~ "Oil"
    assert html =~ "60x40"
  end

  test "a title-less artwork shows Untitled", %{conn: conn} do
    art = ContentFixtures.artwork_fixture(title: "x") |> set_fields(%{"date" => "2020"})
    html = html_response(get(conn, "/art/#{art.id}"), 200)
    assert html =~ "Untitled"
  end

  test "a participant with first and last name is shown by that name", %{conn: conn} do
    art = ContentFixtures.artwork_fixture(title: "Named Maker Work")
    person = ContentFixtures.participant_fixture(first_name: "Ignored", last_name: "Ignored")
    person = set_fields(person, %{"first_name" => "Mara", "last_name" => "Vale"})
    ContentFixtures.link_artwork_to_participant(art, person)

    html = html_response(get(conn, "/art/#{art.id}"), 200)
    assert html =~ "Mara Vale"
  end

  test "a participant with no name at all is shown as Unknown", %{conn: conn} do
    art = ContentFixtures.artwork_fixture(title: "Anonymous Work")
    person = ContentFixtures.participant_fixture(first_name: "x", last_name: "y")
    person = set_fields(person, %{})
    ContentFixtures.link_artwork_to_participant(art, person)

    html = html_response(get(conn, "/art/#{art.id}"), 200)
    assert html =~ "Unknown"
  end
end
