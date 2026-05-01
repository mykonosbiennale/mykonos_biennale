defmodule MykonosBiennale.Content.Biennale do
  @moduledoc """
  Biennale-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship}

  @doc """
  Returns the list of biennales (entities with type "biennale") ordered by year descending.
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "biennale",
        order_by: [desc: fragment("CAST(? ->> ? AS INTEGER)", e.fields, "year")]
    )
  end

  @doc """
  Gets a single biennale entity by ID.

  Raises `Ecto.NoResultsError` if the Entity does not exist.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Gets a biennale entity by year.
  Returns `nil` if not found.
  """
  def get_by_year(year) do
    Repo.one(
      from e in Entity,
        where:
          e.type == "biennale" and fragment("CAST(? ->> ? AS INTEGER)", e.fields, "year") == ^year
    )
  end

  @doc """
  Creates a biennale entity.
  """
  def create(attrs \\ %{}) do
    fields = %{
      "year" => Map.get(attrs, :year) || Map.get(attrs, "year"),
      "theme" => Map.get(attrs, :theme) || Map.get(attrs, "theme"),
      "statement" => Map.get(attrs, :statement) || Map.get(attrs, "statement"),
      "description" => Map.get(attrs, :description) || Map.get(attrs, "description"),
      "start_date" => Map.get(attrs, :start_date) || Map.get(attrs, "start_date"),
      "end_date" => Map.get(attrs, :end_date) || Map.get(attrs, "end_date")
    }

    year = fields["year"]

    Content.create_entity(%{
      identity: to_string(year),
      type: "biennale",
      slug: to_string(year),
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  @doc """
  Updates a biennale entity.
  """
  def update(%Entity{} = biennale_entity, attrs) do
    current_fields = biennale_entity.fields

    new_fields =
      Enum.reduce(
        [:year, :theme, :statement, :description, :start_date, :end_date],
        current_fields,
        fn key, acc ->
          case Map.get(attrs, key) do
            nil -> acc
            value -> Map.put(acc, to_string(key), value)
          end
        end
      )

    Content.update_entity(biennale_entity, %{
      identity: to_string(new_fields["year"]),
      slug: to_string(new_fields["year"]),
      visible: Map.get(attrs, :visible, biennale_entity.visible),
      fields: new_fields
    })
  end

  @doc """
  Deletes a biennale entity and its associated relationships.
  """
  def delete(%Entity{} = biennale_entity) do
    Repo.delete_all(from r in Relationship, where: r.object_id == ^biennale_entity.id)
    Content.delete_entity(biennale_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking biennale entity changes.
  """
  def change(%Entity{} = biennale_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :year) && to_string(Map.get(attrs, :year)),
      slug: Map.get(attrs, :year) && to_string(Map.get(attrs, :year)),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [:year, :theme, :statement, :description, :start_date, :end_date])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(biennale_entity, entity_attrs)
  end
end
