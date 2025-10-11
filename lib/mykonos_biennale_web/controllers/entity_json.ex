defmodule MykonosBiennaleWeb.EntityJSON do
  alias MykonosBiennale.Data.Entity

  @doc """
  Renders a list of entities.
  """
  def index(%{entities: entities}) do
    %{data: for(entity <- entities, do: data(entity))}
  end

  @doc """
  Renders a single entity.
  """
  def show(%{entity: entity}) do
    %{data: data(entity)}
  end

  defp data(%Entity{} = entity) do
    %{
      id: entity.id,
      identity: entity.identity,
      visible: entity.visible,
      fields: entity.fields
    }
  end
end
