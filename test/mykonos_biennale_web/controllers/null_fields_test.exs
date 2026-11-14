defmodule MykonosBiennaleWeb.NullFieldsTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  defp null_fields(entity) do
    entity |> Ecto.Changeset.change(fields: nil) |> Repo.update!()
  end

  test "an artwork with null fields still renders with defaults", %{conn: conn} do
    art = ContentFixtures.artwork_fixture(title: "Null Work") |> null_fields()
    html = html_response(get(conn, "/art/#{art.id}"), 200)
    assert html =~ "Untitled"
  end

  test "a film director with no name renders as Unknown", %{conn: conn} do
    film = ContentFixtures.film_fixture(title: "Unnamed Director Film")
    person = ContentFixtures.participant_fixture() |> null_fields()

    {:ok, _} =
      ContentFixtures.create_relationship(film, person, "directed", %{"roles" => "director"})

    html = html_response(get(conn, "/film/#{film.id}"), 200)
    assert html =~ "Unnamed Director Film"
    assert html =~ "Unknown"
  end
end
