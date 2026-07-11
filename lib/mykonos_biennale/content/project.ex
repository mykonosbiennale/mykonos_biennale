defmodule MykonosBiennale.Content.Project do
  @moduledoc """
  Project-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "project",
        order_by: [desc: e.inserted_at]
    )
  end

  def list_for_biennale(biennale_year) do
    biennale_entity = Content.Biennale.get_by_year(biennale_year)

    if biennale_entity do
      biennale_event_rt_id =
        Repo.one(
          from rt in RelationshipType, where: rt.slug == "biennale_event", select: rt.id, limit: 1
        )

      event_project_rt_id =
        Repo.one(
          from rt in RelationshipType, where: rt.slug == "event_project", select: rt.id, limit: 1
        )

      if biennale_event_rt_id && event_project_rt_id do
        Repo.all(
          from p in Entity,
          join: ep in Relationship,
          on:
            ep.relationship_type_id == ^event_project_rt_id and
              ep.object_id == p.id,
          join: be in Relationship,
          on:
            be.relationship_type_id == ^biennale_event_rt_id and
              be.subject_id == ep.subject_id,
          where: p.type == "project" and be.object_id == ^biennale_entity.id,
          distinct: p.id,
          order_by: [asc: p.identity]
        )
      else
        []
      end
    else
      []
    end
  end

  def get!(id), do: Repo.get!(Entity, id)

  def list_event_media(%Entity{id: project_id}) do
    event_project_rt_id =
      Repo.one(
        from rt in RelationshipType, where: rt.slug == "event_project", select: rt.id, limit: 1
      )

    if event_project_rt_id do
      event_ids =
        Repo.all(
          from r in Relationship,
            where: r.relationship_type_id == ^event_project_rt_id and r.object_id == ^project_id,
            select: r.subject_id
        )

      if event_ids != [] do
        Repo.all(
          from m in Content.Media,
            join: em in "entity_media",
            on: em.media_id == m.id,
            where: em.entity_id in ^event_ids,
            distinct: m.id,
            order_by: fragment("RANDOM()"),
            limit: 1
        )
      else
        []
      end
    else
      []
    end
  end

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
    Repo.delete_all(from r in Relationship, where: r.subject_id == ^project_entity.id)
    Repo.delete_all(from r in Relationship, where: r.object_id == ^project_entity.id)
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
