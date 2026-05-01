defmodule MykonosBiennale.Content.Event do
  @moduledoc """
  Event-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship}

  @doc """
  Returns the list of events (entities with type "event") for a given biennale year.
  Uses relationships to find events linked to the biennale.
  """
  def list_for_biennale(biennale_year) do
    biennale_entity = Content.Biennale.get_by_year(biennale_year)

    if biennale_entity do
      Repo.all(
        from e in Entity,
          join: r in assoc(e, :as_subject),
          where:
            e.type == "event" and r.object_id == ^biennale_entity.id and
              r.slug == "biennale_event",
          order_by: [asc: fragment("? ->> ?", e.fields, "date")]
      )
    else
      []
    end
  end

  @doc """
  Returns the list of events (entities with type "event").
  """
  def list do
    Repo.all(
      from e in Entity,
        where: e.type == "event",
        order_by: [asc: fragment("? ->> ?", e.fields, "date")]
    )
  end

  @doc """
  Returns the list of all events with the associated biennale preloaded via the
  `biennale_event` relationship (used by the admin UI).
  """
  def list_for_admin do
    rel_query = biennale_relationship_query()

    Repo.all(
      from e in Entity,
        where: e.type == "event",
        order_by: [asc: fragment("? ->> ?", e.fields, "date")],
        preload: [as_subject: ^rel_query]
    )
  end

  @doc """
  Gets a single event entity by ID.

  Raises `Ecto.NoResultsError` if the Entity does not exist.
  """
  def get!(id), do: Repo.get!(Entity, id)

  @doc """
  Gets a single event entity by ID with its associated biennale preloaded (admin UI).
  """
  def get_for_admin!(id) do
    Repo.get!(Entity, id) |> Repo.preload(as_subject: biennale_relationship_query())
  end

  @doc """
  Creates an event entity and links it to a biennale via relationship.
  """
  def create(attrs \\ %{}) do
    title = Map.get(attrs, :title) || Map.get(attrs, "title")
    biennale_entity_id = Map.get(attrs, :biennale_id) || Map.get(attrs, "biennale_id")

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
        if biennale_entity_id do
          case Content.get_entity!(biennale_entity_id) do
            %Entity{} = biennale_entity ->
              Content.create_relationship(%{
                name: "belongs_to_biennale",
                slug: "biennale_event",
                fields: %{},
                subject_id: event_entity.id,
                object_id: biennale_entity.id
              })

              {:ok, event_entity}

            _ ->
              {:ok, event_entity}
          end
        else
          {:ok, event_entity}
        end

      error ->
        error
    end
  end

  @doc """
  Updates an event entity and its relationship to a biennale.
  """
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

    case Content.update_entity(event_entity, %{
           identity: title,
           visible: Map.get(attrs, :visible, event_entity.visible),
           fields: new_fields
         }) do
      {:ok, updated_event_entity} ->
        if biennale_entity_id do
          biennale_entity = Content.get_entity!(biennale_entity_id)

          case Repo.get_by(Relationship,
                 subject_id: updated_event_entity.id,
                 slug: "biennale_event"
               ) do
            %Relationship{} = relationship ->
              if relationship.object_id != biennale_entity.id do
                Content.update_relationship(relationship, %{object_id: biennale_entity.id})
              else
                {:ok, relationship}
              end

            _ ->
              Content.create_relationship(%{
                name: "belongs_to_biennale",
                slug: "biennale_event",
                fields: %{},
                subject_id: updated_event_entity.id,
                object_id: biennale_entity.id
              })
          end
        else
          Repo.delete_all(
            from r in Relationship,
              where: r.subject_id == ^updated_event_entity.id and r.slug == "biennale_event"
          )
        end

        {:ok, updated_event_entity}

      error ->
        error
    end
  end

  @doc """
  Deletes an event entity and its associated relationships.
  """
  def delete(%Entity{} = event_entity) do
    Repo.delete_all(from r in Relationship, where: r.subject_id == ^event_entity.id)
    Content.delete_entity(event_entity)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking event entity changes.
  """
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

  defp biennale_relationship_query do
    from r in Relationship,
      where: r.slug == "biennale_event",
      preload: [:object]
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
