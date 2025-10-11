defmodule MykonosBiennale.DataFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MykonosBiennale.Data` context.
  """

  @doc """
  Generate a entity.
  """
  def entity_fixture(attrs \\ %{}) do
    {:ok, entity} =
      attrs
      |> Enum.into(%{
        fields: %{},
        identity: "some identity",
        visible: true
      })
      |> MykonosBiennale.Data.create_entity()

    entity
  end

  @doc """
  Generate a relationship.
  """
  def relationship_fixture(attrs \\ %{}) do
    {:ok, relationship} =
      attrs
      |> Enum.into(%{
        fields: %{},
        name: "some name",
        slug: "some slug"
      })
      |> MykonosBiennale.Data.create_relationship()

    relationship
  end
end
