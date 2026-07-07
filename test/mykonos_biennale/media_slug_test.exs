defmodule MykonosBiennale.MediaSlugTest do
  use ExUnit.Case, async: true

  alias MykonosBiennale.MediaSlug

  describe "encode_id/1" do
    test "produces only lowercase alphanumeric characters (base36)" do
      for id <- 1..500 do
        encoded = MediaSlug.encode_id(id)
        assert Regex.match?(~r/^[0-9a-z]+$/, encoded),
               "ID #{id} produced non-lowercase slug: #{encoded}"
      end
    end

    test "is deterministic" do
      assert MediaSlug.encode_id(588) == MediaSlug.encode_id(588)
    end

    test "produces different encodings for different IDs" do
      ids = Enum.to_list(1..500)
      encodings = Enum.map(ids, &MediaSlug.encode_id/1)
      assert length(Enum.uniq(encodings)) == length(encodings)
    end

    test "no two IDs produce slugs that differ only in case" do
      encodings = Enum.map(Enum.to_list(1..500), &MediaSlug.encode_id/1)
      lowercased = Enum.map(encodings, &String.downcase/1)
      assert length(Enum.uniq(lowercased)) == length(lowercased)
    end
  end

  describe "generate/3" do
    test "uses caption as base when present" do
      slug = MediaSlug.generate(100, "Antidote Box", nil)
      assert String.starts_with?(slug, "antidote-box-")
    end

    test "falls back to original_name when caption is nil" do
      slug = MediaSlug.generate(100, nil, "test-image.jpg")
      assert String.starts_with?(slug, "test-image-jpg-")
    end

    test "falls back to 'media' when both caption and original_name are nil" do
      slug = MediaSlug.generate(100, nil, nil)
      assert String.starts_with?(slug, "media-")
    end

    test "is deterministic for same inputs" do
      assert MediaSlug.generate(42, "Test", "image.jpg") ==
               MediaSlug.generate(42, "Test", "image.jpg")
    end

    test "different IDs produce different slugs" do
      slug1 = MediaSlug.generate(1, "Test", nil)
      slug2 = MediaSlug.generate(2, "Test", nil)
      assert slug1 != slug2
    end

    test "truncates base to 60 characters before appending ID suffix" do
      long_caption = String.duplicate("a", 100)
      slug = MediaSlug.generate(1, long_caption, nil)
      base = slug |> String.replace_suffix("-" <> MediaSlug.encode_id(1), "")
      assert String.length(base) <= 60
    end
  end

  describe "extract_id/1" do
    test "extracts the ID from a generated slug" do
      slug = MediaSlug.generate(42, "Test", nil)
      assert MediaSlug.extract_id(slug) == 42
    end

    test "extracts ID for large IDs" do
      slug = MediaSlug.generate(2836, "Test", nil)
      assert MediaSlug.extract_id(slug) == 2836
    end

    test "returns a number for slugs with valid base36 suffix" do
      assert is_integer(MediaSlug.extract_id("test-016"))
    end

    test "returns -1 for slugs with invalid characters in suffix" do
      assert MediaSlug.extract_id("test-!@#") == -1
    end
  end
end
