defmodule MykonosBiennale.SearchTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Search
  alias MykonosBiennale.Search.Transliterate
  alias MykonosBiennale.Search.Indexer
  alias MykonosBiennale.ContentFixtures

  describe "Transliterate.normalize/1" do
    test "strips diacritics from Latin text" do
      assert Transliterate.normalize("café") == "cafe"
      assert Transliterate.normalize("résumé") == "resume"
    end

    test "strips diacritics from Greek text" do
      result = Transliterate.normalize("έλη")
      assert String.contains?(result, "ελη")
      result2 = Transliterate.normalize("Βενιέρη")
      assert String.contains?(result2, "βενιερη")
    end

    test "handles empty string" do
      assert Transliterate.normalize("") == ""
    end

    test "handles nil" do
      assert Transliterate.normalize(nil) == ""
    end

    test "downcases text" do
      assert Transliterate.normalize("HELLO") == "hello"
    end
  end

  describe "Transliterate.transliterate/1" do
    test "transliterates Greek to Latin" do
      result = Transliterate.normalize("Βενιέρη")
      assert String.contains?(result, "venieri") or String.contains?(result, "benieri")
    end

    test "transliterates simple Greek letters" do
      result = Transliterate.transliterate("αβγ")
      assert String.contains?(result, "abg") or String.contains?(result, "avg")
    end

    test "handles empty string" do
      assert Transliterate.transliterate("") == ""
    end

    test "passes through Latin text unchanged" do
      assert Transliterate.transliterate("hello") == "hello"
    end
  end

  describe "Indexer.build_entity_index/1" do
    test "includes identity in the index" do
      entity = ContentFixtures.artwork_fixture(title: "UniqueArtworkName")
      index = Indexer.build_entity_index(entity)
      assert index =~ "identity:"
      assert String.downcase(index) =~ "uniqueartworkname"
    end

    test "includes entity type" do
      entity = ContentFixtures.artwork_fixture()
      index = Indexer.build_entity_index(entity)
      assert index =~ "type:"
      assert index =~ "artwork"
    end

    test "includes slug" do
      entity = ContentFixtures.artwork_fixture()
      index = Indexer.build_entity_index(entity)
      assert index =~ "slug:"
    end
  end

  describe "Search.search/2" do
    test "returns empty results for empty query" do
      results = Search.search("")
      assert results.total == 0
    end

    test "finds entities by title" do
      entity = ContentFixtures.artwork_fixture(title: "FindableArtworkXYZ")
      Indexer.index_entity(entity.id)
      results = Search.search("FindableArtworkXYZ")
      assert Enum.any?(results.artworks, &(&1.id == entity.id))
    end

    test "is case-insensitive" do
      entity = ContentFixtures.artwork_fixture(title: "MixedCaseTitle")
      Indexer.index_entity(entity.id)
      results = Search.search("mixedcasetitle")
      assert Enum.any?(results.artworks, &(&1.id == entity.id))
    end
  end
end
