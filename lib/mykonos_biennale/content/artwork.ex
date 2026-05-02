defmodule MykonosBiennale.Content.Artwork do
  @moduledoc """
  Artwork-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

  @doc """
  Returns the list of artworks ordered by date descending.
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "artwork",
        order_by: [desc: fragment("? ->> ?", e.fields, "date")]
    )
  end

  @doc """
  Gets a single artwork entity by ID.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates an artwork entity.
  """
  def create(attrs \\ %{}) do
    title = Map.get(attrs, :title) || Map.get(attrs, "title") || ""

    fields = %{
      "title" => title,
      "date" => Map.get(attrs, :date) || Map.get(attrs, "date"),
      "description" => Map.get(attrs, :description) || Map.get(attrs, "description"),
      "medium" => Map.get(attrs, :medium) || Map.get(attrs, "medium"),
      "size" => Map.get(attrs, :size) || Map.get(attrs, "size"),
      "type" => Map.get(attrs, :type) || Map.get(attrs, "type")
    }

    slug = Content.slugify(title) <> "-#{System.monotonic_time()}"

    Content.create_entity(%{
      identity: title,
      type: "artwork",
      slug: slug,
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  @doc """
  Updates an artwork entity.
  """
  def update(%Entity{} = artwork_entity, attrs) do
    current_fields = artwork_entity.fields

    new_fields =
      Enum.reduce([:title, :date, :description, :medium, :size, :type], current_fields, fn key,
                                                                                           acc ->
        case Map.get(attrs, key) do
          nil -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    title = Map.get(attrs, :title) || new_fields["title"]

    Content.update_entity(artwork_entity, %{
      identity: title,
      visible: Map.get(attrs, :visible, artwork_entity.visible),
      fields: new_fields
    })
  end

  @doc """
  Deletes an artwork entity.
  """
  def delete(%Entity{} = artwork_entity) do
    Content.delete_entity(artwork_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking artwork entity changes.
  """
  def change(%Entity{} = artwork_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :title),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [:title, :date, :description, :medium, :size, :type])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(artwork_entity, entity_attrs)
  end
end
