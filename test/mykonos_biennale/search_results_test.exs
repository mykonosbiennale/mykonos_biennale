defmodule MykonosBiennale.SearchResultsTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Search
  alias MykonosBiennale.Search.Indexer

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  defp index!(entity) do
    {:ok, _} = Indexer.index_entity(entity.id)
    entity
  end

  test "each entity type is presented with its title, subtitle and url" do
    index!(ContentFixtures.biennale_fixture(year: 2024, theme: "Harbour Theme"))
    index!(ContentFixtures.artwork_fixture(title: "Harbour Work"))
    index!(ContentFixtures.film_fixture(title: "Harbour Film", type: "Video"))
    index!(ContentFixtures.event_fixture(title: "Harbour Event"))

    res = Search.search("harbour", limit: 20)

    [bienn] = res.biennales
    assert bienn.url == "/archive/2024"
    assert bienn.subtitle == "Harbour Theme"

    [art] = res.artworks
    assert art.title == "Harbour Work"
    assert art.url =~ "/art/"

    [film] = res.films
    assert film.title == "Harbour Film"
    assert film.subtitle =~ "Video"

    assert res.total >= 4
  end

  test "a participant is found by name and presented as an artist" do
    person =
      ContentFixtures.participant_fixture(first_name: "Lena", last_name: "Harbourwright")
      |> Ecto.Changeset.change(fields: %{"first_name" => "Lena", "last_name" => "Harbourwright"})
      |> Repo.update!()

    index!(person)
    res = Search.search("harbourwright", limit: 20)
    assert [hit | _] = res.participants
    assert hit.title == "Lena Harbourwright"
    assert hit.subtitle =~ "Artist"
  end

  test "a term with no matches returns no hits" do
    res = Search.search("zzz-no-such-thing-zzz", limit: 20)
    assert res.total == 0
  end
end
