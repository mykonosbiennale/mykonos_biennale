defmodule MykonosBiennaleWeb.ParticipantPageTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  test "lists artworks with and without media, and films with their type labels", %{conn: conn} do
    person = ContentFixtures.participant_fixture(first_name: "Pat", last_name: "Maker")

    with_media = ContentFixtures.artwork_fixture(title: "Pictured Work")
    photo = ContentFixtures.media_fixture(caption: "Pictured photo")
    MykonosBiennale.Content.attach_media_to_entity(with_media, photo, metadata: %{})
    ContentFixtures.link_artwork_to_participant(with_media, person)

    without_media = ContentFixtures.artwork_fixture(title: "Bare Work")
    ContentFixtures.link_artwork_to_participant(without_media, person)

    dance = ContentFixtures.film_fixture(title: "Dance Piece", type: "Dance")

    {:ok, _} =
      ContentFixtures.create_relationship(dance, person, "directed", %{"roles" => "choreographer"})

    short = ContentFixtures.film_fixture(title: "Short Piece", type: "Short Film")

    {:ok, _} =
      ContentFixtures.create_relationship(short, person, "directed", %{"roles" => "director"})

    html = html_response(get(conn, "/artist/#{person.id}"), 200)
    assert html =~ "Pictured Work"
    assert html =~ "Bare Work"
    assert html =~ "Pat Maker"
  end
end
