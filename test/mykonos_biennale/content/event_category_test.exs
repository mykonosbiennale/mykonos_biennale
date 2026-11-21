defmodule MykonosBiennale.Content.EventCategoryTest do
  use ExUnit.Case, async: true

  alias MykonosBiennale.Content.EventCategory

  test "every stored type belongs to exactly one category" do
    stored = ~w(exhibition screening performance workshop celebration event)

    for type <- stored do
      assert EventCategory.key_for_type(type) in ["art_show", "screening", "event"]
    end

    all_types = EventCategory.all() |> Enum.flat_map(& &1.types)
    assert Enum.sort(all_types) == Enum.sort(stored)
  end

  test "maps stored types to their category" do
    assert EventCategory.key_for_type("exhibition") == "art_show"
    assert EventCategory.key_for_type("screening") == "screening"
    assert EventCategory.key_for_type("performance") == "event"
    assert EventCategory.key_for_type("celebration") == "event"
  end

  test "unknown or missing types have no category" do
    assert EventCategory.key_for_type("gala") == nil
    assert EventCategory.key_for_type(nil) == nil
  end

  test "type_label gives a readable label and falls back to the raw value" do
    assert EventCategory.type_label("celebration") == "Celebration"
    assert EventCategory.type_label("gala") == "gala"
    assert EventCategory.type_label(nil) == "Untyped"
  end
end
