defmodule MykonosBiennaleWeb.FilmHTMLTest do
  use ExUnit.Case, async: true

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennaleWeb.FilmHTML

  describe "field/3" do
    test "reads atom and string keys and falls back to the default" do
      entity = %Entity{fields: %{"title" => "Atom and string", "year" => 2025}}
      assert FilmHTML.field(entity, :title) == "Atom and string"
      assert FilmHTML.field(entity, "year") == 2025
      assert FilmHTML.field(entity, :missing, "fallback") == "fallback"
    end

    test "non-entities and entities without fields return the default" do
      assert FilmHTML.field(nil, :title, "none") == "none"
      assert FilmHTML.field(%Entity{fields: nil}, :title, "none") == "none"
    end
  end

  describe "trailer_embed/1" do
    test "a non-empty embed is returned as raw HTML" do
      assert Phoenix.HTML.safe_to_string(FilmHTML.trailer_embed("<iframe></iframe>")) ==
               "<iframe></iframe>"
    end

    test "nil, empty and other values produce nothing" do
      assert FilmHTML.trailer_embed(nil) == nil
      assert FilmHTML.trailer_embed("") == nil
      assert FilmHTML.trailer_embed(42) == nil
    end
  end

  describe "media_url/2" do
    test "delegates to the uploads module" do
      assert FilmHTML.media_url(nil, []) == MykonosBiennale.Uploads.media_url(nil, [])
    end
  end
end
