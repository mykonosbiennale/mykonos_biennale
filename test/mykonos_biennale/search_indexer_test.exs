defmodule MykonosBiennale.SearchIndexerTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Search.Indexer

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  describe "index_entity/1" do
    test "returns not_found for an unknown id" do
      assert Indexer.index_entity(-1) == {:error, :not_found}
    end

    test "stores a searchable index and a timestamp" do
      art = ContentFixtures.artwork_fixture(title: "Indexed Canvas")
      assert {:ok, _} = Indexer.index_entity(art.id)

      stored = Repo.get!(Entity, art.id)
      assert is_binary(stored.search_index)
      assert stored.search_index =~ "indexed canvas"
      assert stored.search_indexed_at
    end

    test "a participant is indexed by first and last name" do
      person =
        ContentFixtures.participant_fixture(first_name: "Dora", last_name: "Quill")
        |> Ecto.Changeset.change(fields: %{"first_name" => "Dora", "last_name" => "Quill"})
        |> Repo.update!()

      assert Indexer.build_entity_index(person) =~ "dora quill"
    end

    test "a participant with a name field is indexed by that name" do
      person =
        ContentFixtures.participant_fixture()
        |> Ecto.Changeset.change(fields: %{"name" => "Named Only"})
        |> Repo.update!()

      assert Indexer.build_entity_index(person) =~ "named only"
    end
  end

  describe "index_media/1" do
    test "returns not_found for an unknown id" do
      assert Indexer.index_media(-1) == {:error, :not_found}
    end

    test "indexes caption, alt text and mime type" do
      media =
        ContentFixtures.media_fixture(caption: "Harbour Shot")
        |> Ecto.Changeset.change(alt_text: "a pier at dusk", mime_type: "image/jpeg")
        |> Repo.update!()

      assert {:ok, _} = Indexer.index_media(media.id)
      stored = Repo.get!(Media, media.id)
      assert stored.search_index =~ "harbour shot"
      assert stored.search_index =~ "a pier at dusk"
      assert stored.search_index =~ "image/jpeg"
    end

    test "media inherits the index of the entity it is attached to" do
      art = ContentFixtures.artwork_fixture(title: "Inherited Title")
      {:ok, _} = Indexer.index_entity(art.id)
      media = ContentFixtures.media_fixture(caption: "Plain")
      Content.attach_media_to_entity(art, media, metadata: %{})

      index = Indexer.build_media_index(Repo.get!(Media, media.id))
      assert index =~ "inherited title"
    end

    test "build_media_index ignores empty sections" do
      media = ContentFixtures.media_fixture(caption: nil)
      assert is_binary(Indexer.build_media_index(media))
    end
  end

  describe "normalize_query/1" do
    test "lowercases and handles nil and non-strings" do
      assert Indexer.normalize_query("Ελλάδα") != nil
      assert Indexer.normalize_query("MIXED Case") =~ "mixed case"
      assert is_binary(Indexer.normalize_query(nil))
      assert is_binary(Indexer.normalize_query(12))
    end
  end
end
