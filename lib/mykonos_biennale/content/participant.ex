defmodule MykonosBiennale.Content.Participant do
  @moduledoc """
  Participant-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity

  @doc """
  Returns the list of participants ordered by last name.
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "participant",
        order_by: [asc: fragment("? ->> ?", e.fields, "last_name")]
    )
  end

  @doc """
  Gets a single participant entity by ID.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates a participant entity.
  """
  def create(attrs \\ %{}) do
    first_name = Map.get(attrs, :first_name) || Map.get(attrs, "first_name") || ""
    last_name = Map.get(attrs, :last_name) || Map.get(attrs, "last_name") || ""
    name = Map.get(attrs, :name) || Map.get(attrs, "name") || "#{first_name} #{last_name}"

    fields = %{
      "first_name" => first_name,
      "last_name" => last_name,
      "name" => name,
      "country" => Map.get(attrs, :country) || Map.get(attrs, "country"),
      "email" => Map.get(attrs, :email) || Map.get(attrs, "email"),
      "phone" => Map.get(attrs, :phone) || Map.get(attrs, "phone"),
      "website" => Map.get(attrs, :website) || Map.get(attrs, "website"),
      "social_media" => Map.get(attrs, :social_media) || Map.get(attrs, "social_media") || [],
      "bio" => Map.get(attrs, :bio) || Map.get(attrs, "bio"),
      "statement" => Map.get(attrs, :statement) || Map.get(attrs, "statement")
    }

    slug = Content.slugify("#{first_name}-#{last_name}") <> "-#{System.monotonic_time()}"

    Content.create_entity(%{
      identity: name,
      type: "participant",
      slug: slug,
      visible: Map.get(attrs, :visible, true),
      fields: fields
    })
  end

  @doc """
  Updates a participant entity.
  """
  def update(%Entity{} = participant_entity, attrs) do
    current_fields = participant_entity.fields

    update_keys = [
      :first_name,
      :last_name,
      :name,
      :country,
      :email,
      :phone,
      :website,
      :social_media,
      :bio,
      :statement
    ]

    new_fields =
      Enum.reduce(update_keys, current_fields, fn key, acc ->
        case Map.get(attrs, key) do
          nil -> acc
          value -> Map.put(acc, to_string(key), value)
        end
      end)

    name = Map.get(attrs, :name) || new_fields["name"]

    Content.update_entity(participant_entity, %{
      identity: name,
      visible: Map.get(attrs, :visible, participant_entity.visible),
      fields: new_fields
    })
  end

  @doc """
  Deletes a participant entity.
  """
  def delete(%Entity{} = participant_entity) do
    Content.delete_entity(participant_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking participant entity changes.
  """
  def change(%Entity{} = participant_entity, attrs \\ %{}) do
    entity_attrs = %{
      identity: Map.get(attrs, :name),
      visible: Map.get(attrs, :visible),
      fields:
        Map.take(attrs, [
          :first_name,
          :last_name,
          :name,
          :country,
          :email,
          :phone,
          :website,
          :social_media,
          :bio,
          :statement
        ])
        |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    }

    Entity.changeset(participant_entity, entity_attrs)
  end
end
