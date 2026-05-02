defmodule MykonosBiennale.Content.Project do
  @moduledoc """
  Project-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "project",
        order_by: [desc: e.inserted_at]
    )
  end

  def get!(id), do: Repo.get!(Entity, id)

  def create(attrs \\ %{}) do
    title = Map.get(attrs, :title) || Map.get(attrs, "title") || ""

    fields = %{
      "title" => title,
      "description" => Map.get(attrs, :description) || Map.get(attrs, "description"),
      "statement" => Map.get(attrs, :statement) || Map.get(attrs, "statement")
    }

    slug = Content.slugify(title) <> "-#{System.monotonic_time()}"

    Content.create_entity(%{
      identity: title,
      type: "project",
      slug: slug,
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  def update(%Entity{} = project_entity, attrs) do
    current_fields = project_entity.fields

    new_fields =
      Enum.reduce([:title, :description, :statement], current_fields, fn key, acc ->
        case Map.get(attrs, key) do
          nil -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    title = Map.get(attrs, :title) || new_fields["title"]

    Content.update_entity(project_entity, %{
      identity: title,
      visible: Map.get(attrs, :visible, project_entity.visible),
      fields: new_fields
    })
  end

  def delete(%Entity{} = project_entity) do
    Content.delete_entity(project_entity)
  end

  def change(%Entity{} = project_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :title),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [:title, :description, :statement])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(project_entity, entity_attrs)
  end
end
