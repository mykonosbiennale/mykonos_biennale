defmodule MykonosBiennale.Content.Festival do
  @moduledoc """
  Festival-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

  @doc """
  Returns the list of festivals (entities with type "festival") ordered by year descending.
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "festival",
        order_by: [desc: fragment("CAST(? ->> ? AS INTEGER)", e.fields, "year")]
    )
  end

  @doc """
  Gets a single festival entity by ID.

  Raises `Ecto.NoResultsError` if the Entity does not exist.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates a festival entity.
  """
  def create(attrs \\ %{}) do
    fields = %{
      "year" => Map.get(attrs, :year) || Map.get(attrs, "year"),
      "title" => Map.get(attrs, :title) || Map.get(attrs, "title"),
      "statement" => Map.get(attrs, :statement) || Map.get(attrs, "statement"),
      "template" => Map.get(attrs, :template) || Map.get(attrs, "template"),
      "css" => Map.get(attrs, :css) || Map.get(attrs, "css")
    }

    year = fields["year"]

    Content.create_entity(%{
      identity: to_string(year),
      type: "festival",
      slug: to_string(year),
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  @doc """
  Updates a festival entity.
  """
  def update(%Entity{} = festival_entity, attrs) do
    current_fields = festival_entity.fields

    new_fields =
      Enum.reduce(
        [:year, :title, :statement, :template, :css],
        current_fields,
        fn key, acc ->
          case Map.get(attrs, key) do
            nil -> acc
            value -> Map.put(acc, to_string(key), value)
          end
        end
      )

    Content.update_entity(festival_entity, %{
      identity: to_string(new_fields["year"]),
      slug: to_string(new_fields["year"]),
      visible: Map.get(attrs, :visible, festival_entity.visible),
      fields: new_fields
    })
  end

  @doc """
  Deletes a festival entity.
  """
  def delete(%Entity{} = festival_entity) do
    Content.delete_entity(festival_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking festival entity changes.
  """
  def change(%Entity{} = festival_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :year) && to_string(Map.get(attrs, :year)),
      slug: Map.get(attrs, :year) && to_string(Map.get(attrs, :year)),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [:year, :title, :statement, :template, :css])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(festival_entity, entity_attrs)
  end
end
