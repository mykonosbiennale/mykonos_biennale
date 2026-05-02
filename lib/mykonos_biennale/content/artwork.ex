defmodule MykonosBiennale.Content.Artwork do
  @moduledoc """
  Artwork-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  @type_to_rel_name %{
    "film" => "screened",
    "video" => "screened",
    "artwork" => "shown",
    "performance" => "performed"
  }

  def relationship_name_for_type(type) do
    Map.get(@type_to_rel_name, type, "shown")
  end

  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "artwork",
        order_by: [desc: fragment("? ->> ?", e.fields, "date")]
    )
  end

  def get!(id), do: Repo.get!(Entity, id)

  def get_for_admin!(id) do
    rt_subq =
      from rt in RelationshipType, where: rt.slug == "artwork_event", select: rt.id, limit: 1

    rel_query =
      from r in Relationship,
        where: r.relationship_type_id in subquery(rt_subq),
        preload: [:object, :relationship_type]

    Repo.get!(Entity, id) |> Repo.preload(as_subject: rel_query)
  end

  def list_linked_events(%Entity{} = artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object, :relationship_type]
      )
    else
      []
    end
  end

  def attach_event(%Entity{} = artwork, %Entity{} = event) do
    rel_label = relationship_name_for_type(artwork.fields["type"])

    Content.create_relationship(%{
      label: rel_label,
      slug: "artwork_event",
      fields: %{},
      subject_id: artwork.id,
      object_id: event.id
    })
  end

  def detach_event(%Entity{} = artwork, event_id) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_event")

    if rt do
      case Repo.get_by(Relationship,
             subject_id: artwork.id,
             relationship_type_id: rt.id,
             object_id: event_id
           ) do
        %Relationship{} = rel -> Content.delete_relationship(rel)
        nil -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

  def list_linked_participants(%Entity{} = artwork) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^artwork.id and r.relationship_type_id == ^rt.id,
          preload: [:object, :relationship_type]
      )
    else
      []
    end
  end

  def attach_participant(%Entity{} = artwork, %Entity{} = participant, role) do
    rel_label = relationship_name_for_type(artwork.fields["type"])

    Content.create_relationship(%{
      label: "involved",
      slug: "artwork_participant",
      fields: %{"role" => role, "label" => rel_label},
      subject_id: artwork.id,
      object_id: participant.id
    })
  end

  def detach_participant(%Entity{} = artwork, participant_id) do
    rt = Repo.get_by(RelationshipType, slug: "artwork_participant")

    if rt do
      case Repo.get_by(Relationship,
             subject_id: artwork.id,
             relationship_type_id: rt.id,
             object_id: participant_id
           ) do
        %Relationship{} = rel -> Content.delete_relationship(rel)
        nil -> {:error, :not_found}
      end
    else
      {:error, :not_found}
    end
  end

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
