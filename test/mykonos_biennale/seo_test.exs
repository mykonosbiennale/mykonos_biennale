defmodule MykonosBiennale.SEOTest do
  use ExUnit.Case, async: true

  alias MykonosBiennale.SEO
  alias MykonosBiennaleWeb.Metadata

  describe "defaults/1" do
    test "artwork uses its title and description" do
      entity = %{type: "artwork", fields: %{"title" => "Blue", "description" => "Oil on canvas"}}

      assert SEO.defaults(entity) == %{title: "Blue", description: "Oil on canvas"}
    end

    test "biennale title combines theme and year" do
      entity = %{type: "biennale", fields: %{"theme" => "Water", "year" => "2025"}}

      assert SEO.defaults(entity).title == "Mykonos Biennale 2025"
    end

    test "participant uses identity and bio" do
      entity = %{type: "participant", identity: "Maria", fields: %{"bio" => "Painter"}}

      assert SEO.defaults(entity) == %{title: "Maria", description: "Painter"}
    end

    test "films use identity and synopsis" do
      entity = %{type: "Documentary", identity: "The Film", fields: %{"synopsis" => "A story"}}

      assert SEO.defaults(entity) == %{title: "The Film", description: "A story"}
    end

    test "unknown entities and nil give no defaults" do
      assert SEO.defaults(nil) == %{title: nil, description: nil}
      assert SEO.defaults(%{type: "sponsor", fields: %{}}) == %{title: nil, description: nil}
    end
  end

  describe "overrides_from_params/2" do
    @defaults %{title: "Blue", description: "Oil on canvas"}

    test "stores only values that differ from the automatic default" do
      params = %{"title" => "Blue", "description" => "A new description"}

      assert SEO.overrides_from_params(params, @defaults) == %{
               "description" => "A new description"
             }
    end

    test "blank values are not stored, so the automatic value is used again" do
      assert SEO.overrides_from_params(%{"title" => "   ", "description" => ""}, @defaults) == %{}
    end

    test "noindex is stored only when checked" do
      assert SEO.overrides_from_params(%{"noindex" => "true"}, @defaults) == %{"noindex" => true}
      assert SEO.overrides_from_params(%{}, @defaults) == %{}
    end

    test "nil params store nothing" do
      assert SEO.overrides_from_params(nil, @defaults) == %{}
    end
  end

  describe "metadata overrides" do
    test "an entity's stored title and noindex replace the computed ones" do
      artwork = %{
        type: "artwork",
        fields: %{"title" => "Blue"},
        seo: %{"title" => "Custom title", "noindex" => true}
      }

      seo = Metadata.for_artwork(artwork, nil, nil, "/artwork/1")

      assert seo.title == "Custom title"
      assert seo.robots == "noindex, nofollow"
    end

    test "without overrides the computed values are used" do
      artwork = %{type: "artwork", fields: %{"title" => "Blue"}, seo: %{}}

      seo = Metadata.for_artwork(artwork, nil, nil, "/artwork/1")

      assert seo.title == "Blue"
      assert seo.robots == nil
    end
  end
end
