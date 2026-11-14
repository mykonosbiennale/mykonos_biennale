defmodule MykonosBiennaleWeb.MetadataTest do
  use ExUnit.Case, async: true

  alias MykonosBiennaleWeb.Metadata

  defp entity(fields), do: %{fields: fields}

  describe "iso_date/1" do
    test "accepts full ISO dates" do
      assert Metadata.iso_date("2025-09-27") == "2025-09-27"
      assert Metadata.iso_date(" 2025-09-27 ") == "2025-09-27"
    end

    test "rejects year-only and invalid values" do
      assert Metadata.iso_date("2015") == nil
      assert Metadata.iso_date("27/09/2025") == nil
      assert Metadata.iso_date("") == nil
      assert Metadata.iso_date(nil) == nil
    end
  end

  describe "plain_text/1" do
    test "strips tags, decodes &amp; and collapses whitespace" do
      assert Metadata.plain_text("<p>Art &amp;  film</p>\n<p>today</p>") == "Art & film today"
    end

    test "returns nil for empty input" do
      assert Metadata.plain_text(nil) == nil
      assert Metadata.plain_text("<p>  </p>") == nil
    end
  end

  describe "for_biennale/2" do
    test "emits an Event with dates when they are full ISO dates" do
      biennale =
        entity(%{
          "year" => "2025",
          "statement" => "<p>The statement</p>",
          "start_date" => "2025-09-27",
          "end_date" => "2025-10-05"
        })

      seo = Metadata.for_biennale(biennale, "/biennale/2025")

      assert seo.canonical_url =~ "/biennale/2025"
      assert seo.description == "The statement"
      assert %{"@type" => "Event", "name" => "Mykonos Biennale 2025"} = seo.jsonld
      assert seo.jsonld["startDate"] == "2025-09-27"
      assert seo.jsonld["endDate"] == "2025-10-05"
      assert seo.jsonld["description"] == "The statement"
    end

    test "omits dates that are not full ISO dates" do
      seo = Metadata.for_biennale(entity(%{"year" => "2015"}), "/biennale/2015")

      refute Map.has_key?(seo.jsonld, "startDate")
      refute Map.has_key?(seo.jsonld, "endDate")
    end
  end

  describe "for_event/3" do
    test "combines date and time into startDate" do
      event = entity(%{"title" => "Opening", "date" => "2025-09-27", "time" => "9:30"})

      seo = Metadata.for_event(event, "2025", "/event/1")

      assert seo.jsonld["startDate"] == "2025-09-27T09:30"
      assert seo.jsonld["isPartOf"] == %{"@type" => "Event", "name" => "Mykonos Biennale 2025"}
    end

    test "keeps the date alone when there is no time" do
      event = entity(%{"title" => "Opening", "date" => "2025-09-27"})

      assert Metadata.for_event(event, nil, "/event/1").jsonld["startDate"] == "2025-09-27"
    end

    test "omits startDate for a year-only date and adds a location when given" do
      event = entity(%{"title" => "Old", "date" => "2015", "location" => "Harbour"})

      seo = Metadata.for_event(event, "2015", "/event/2")

      refute Map.has_key?(seo.jsonld, "startDate")
      assert seo.jsonld["location"] == %{"@type" => "Place", "name" => "Harbour"}
      assert Map.has_key?(seo.jsonld, "isPartOf")
    end
  end

  describe "for_artwork/3" do
    test "names the artist as creator when there is one" do
      artwork = entity(%{"title" => "Blue", "medium" => "Oil"})

      seo = Metadata.for_artwork(artwork, "Maria", "/artwork/1")

      assert seo.jsonld["creator"] == %{"@type" => "Person", "name" => "Maria"}
      assert seo.jsonld["artMedium"] == "Oil"
      assert seo.title == "Blue"
    end

    test "leaves creator out when the artist is unknown" do
      seo = Metadata.for_artwork(entity(%{"title" => "Blue"}), nil, "/artwork/1")

      refute Map.has_key?(seo.jsonld, "creator")
    end
  end

  describe "noindex/0" do
    test "asks search engines not to index the page" do
      assert Metadata.noindex() == %{robots: "noindex, nofollow"}
    end
  end
end
