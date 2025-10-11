defmodule MykonosBiennaleWeb.RelationshipJSON do
  alias MykonosBiennale.Data.Relationship

  @doc """
  Renders a list of relationships.
  """
  def index(%{relationships: relationships}) do
    %{data: for(relationship <- relationships, do: data(relationship))}
  end

  @doc """
  Renders a single relationship.
  """
  def show(%{relationship: relationship}) do
    %{data: data(relationship)}
  end

  defp data(%Relationship{} = relationship) do
    %{
      id: relationship.id,
      name: relationship.name,
      slug: relationship.slug,
      fields: relationship.fields
    }
  end
end
