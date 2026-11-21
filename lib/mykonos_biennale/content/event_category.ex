defmodule MykonosBiennale.Content.EventCategory do
  @moduledoc """
  The three categories offered by the quick event form. Each groups the existing
  stored event types (`fields["type"]`). The stored values are unchanged.
  """

  @categories [
    %{key: "art_show", label: "Art show", types: ["exhibition"]},
    %{key: "screening", label: "Screening", types: ["screening"]},
    %{key: "event", label: "Event", types: ["performance", "workshop", "celebration", "event"]}
  ]

  @type_labels %{
    "exhibition" => "Exhibition",
    "screening" => "Screening",
    "performance" => "Performance",
    "workshop" => "Workshop",
    "celebration" => "Celebration",
    "event" => "Event"
  }

  @doc "All categories, in display order."
  def all, do: @categories

  @doc "The category with the given key, or nil."
  def get(key), do: Enum.find(@categories, &(&1.key == key))

  @doc "The stored types a category groups."
  def types(key) do
    case get(key) do
      nil -> []
      category -> category.types
    end
  end

  @doc "The category key for a stored type, or nil when the type is unknown."
  def key_for_type(type) do
    case Enum.find(@categories, &(type in &1.types)) do
      nil -> nil
      category -> category.key
    end
  end

  @doc "Human label for a stored type."
  def type_label(type), do: Map.get(@type_labels, type, type || "Untyped")
end
