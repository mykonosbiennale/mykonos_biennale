defmodule MykonosBiennale.Content.Event do
  @moduledoc """
  Event-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  def list_for_biennale(biennale_year) do
    biennale_entity = Content.Biennale.get_by_year(biennale_year)

    if biennale_entity do
      rt_subq =
        from rt in RelationshipType, where: rt.slug == "biennale_event", select: rt.id, limit: 1

      Repo.all(
        from e in Entity,
          join: r in assoc(e, :as_subject),
          where:
            e.type == "event" and r.object_id == ^biennale_entity.id and
              r.relationship_type_id in subquery(rt_subq),
          order_by: [asc: fragment("? ->> ?", e.fields, "date")]
      )
    else
      []
    end
  end

  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "event",
        order_by: [asc: fragment("? ->> ?", e.fields, "date")]
    )
  end

  def list_for_admin do
    rel_query = admin_relationship_query()

    Repo.all(
      from e in Entity,
        where: e.type == "event",
        order_by: [asc: fragment("? ->> ?", e.fields, "date")],
        preload: [as_subject: ^rel_query]
    )
  end

  def get!(id), do: Repo.get!(Entity, id)

  def get_for_admin!(id) do
    Repo.get!(Entity, id) |> Repo.preload(as_subject: admin_relationship_query())
  end

  def create(attrs \\ %{}) do
    title = Map.get(attrs, :title) || Map.get(attrs, "title")
    biennale_entity_id = Map.get(attrs, :biennale_id) || Map.get(attrs, "biennale_id")
    festival_entity_id = Map.get(attrs, :festival_id) || Map.get(attrs, "festival_id")
    project_entity_id = Map.get(attrs, :project_id) || Map.get(attrs, "project_id")

    fields = %{
      "title" => title,
      "description" => Map.get(attrs, :description) || Map.get(attrs, "description"),
      "type" => Map.get(attrs, :type) || Map.get(attrs, "type"),
      "date" => Map.get(attrs, :date) || Map.get(attrs, "date"),
      "time" => Map.get(attrs, :time) || Map.get(attrs, "time"),
      "location" => Map.get(attrs, :location) || Map.get(attrs, "location"),
      "tickets" => Map.get(attrs, :tickets) || Map.get(attrs, "tickets")
    }

    slug = "#{slugify(title || "event")}-#{System.monotonic_time()}"

    case Content.create_entity(%{
           identity: title,
           type: "event",
           slug: slug,
           visible: Map.get(attrs, :visible, true),
           fields: fields
         }) do
      {:ok, event_entity} ->
        maybe_create_relationship(
          event_entity,
          biennale_entity_id,
          "belongs_to_biennale",
          "biennale_event"
        )

        maybe_create_relationship(event_entity, festival_entity_id, "part_of", "event_festival")
        maybe_create_relationship(event_entity, project_entity_id, "is_a", "event_project")
        {:ok, event_entity}

      error ->
        error
    end
  end

  def update(%Entity{} = event_entity, attrs) do
    current_fields = event_entity.fields

    new_fields =
      Enum.reduce(
        [:title, :description, :type, :date, :time, :location, :tickets],
        current_fields,
        fn key, acc ->
          case Map.get(attrs, key) do
            nil -> acc
            value -> Map.put(acc, to_string(key), value)
          end
        end
      )

    title = Map.get(attrs, :title) || new_fields["title"]
    biennale_entity_id = Map.get(attrs, :biennale_id) || Map.get(attrs, "biennale_id")
    festival_entity_id = Map.get(attrs, :festival_id) || Map.get(attrs, "festival_id")
    project_entity_id = Map.get(attrs, :project_id) || Map.get(attrs, "project_id")

    case Content.update_entity(event_entity, %{
           identity: title,
           visible: Map.get(attrs, :visible, event_entity.visible),
           fields: new_fields
         }) do
      {:ok, updated_event_entity} ->
        maybe_upsert_relationship(
          updated_event_entity,
          biennale_entity_id,
          "belongs_to_biennale",
          "biennale_event"
        )

        maybe_upsert_relationship(
          updated_event_entity,
          festival_entity_id,
          "part_of",
          "event_festival"
        )

        maybe_upsert_relationship(
          updated_event_entity,
          project_entity_id,
          "is_a",
          "event_project"
        )

        {:ok, updated_event_entity}

      error ->
        error
    end
  end

  def delete(%Entity{} = event_entity) do
    Repo.delete_all(from r in Relationship, where: r.subject_id == ^event_entity.id)
    Content.delete_entity(event_entity)
  end

  def change(%Entity{} = event_entity, attrs \\ %{}) do
    event_fields_to_map = [:title, :description, :type, :date, :time, :location, :tickets]

    fields_map =
      Map.take(attrs, event_fields_to_map)
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)

    entity_attrs = %{
      identity: Map.get(attrs, :title),
      visible: Map.get(attrs, :visible),
      fields: fields_map
    }

    Entity.changeset(event_entity, entity_attrs)
  end

  defp admin_relationship_query do
    rt_ids =
      from rt in RelationshipType,
        where: rt.slug in ^["biennale_event", "event_festival", "event_project"],
        select: rt.id

    from r in Relationship,
      where: r.relationship_type_id in subquery(rt_ids),
      preload: [:object, :relationship_type]
  end

  defp maybe_create_relationship(_event_entity, nil, _label, _slug), do: nil

  defp maybe_create_relationship(event_entity, entity_id, label, slug) do
    case Content.get_entity!(entity_id) do
      %Entity{} = target ->
        Content.create_relationship(%{
          label: label,
          slug: slug,
          fields: %{},
          subject_id: event_entity.id,
          object_id: target.id
        })

      _ ->
        nil
    end
  end

  defp maybe_upsert_relationship(event_entity, nil, _label, slug) do
    case Repo.get_by(RelationshipType, slug: slug) do
      nil ->
        :ok

      rt ->
        Repo.delete_all(
          from r in Relationship,
            where: r.subject_id == ^event_entity.id and r.relationship_type_id == ^rt.id
        )
    end
  end

  defp maybe_upsert_relationship(event_entity, entity_id, label, slug) do
    target = Content.get_entity!(entity_id)
    rt = Repo.get_by!(RelationshipType, slug: slug)

    case Repo.get_by(Relationship, subject_id: event_entity.id, relationship_type_id: rt.id) do
      %Relationship{} = relationship ->
        if relationship.object_id != target.id do
          Content.update_relationship(relationship, %{object_id: target.id})
        end

      _ ->
        Content.create_relationship(%{
          label: label,
          slug: slug,
          fields: %{},
          subject_id: event_entity.id,
          object_id: target.id
        })
    end
  end

  defp slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim_leading("-")
    |> String.trim_trailing("-")
  end
end
