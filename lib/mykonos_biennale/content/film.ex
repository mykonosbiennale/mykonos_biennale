defmodule MykonosBiennale.Content.Film do
  @moduledoc """
  Film-specific operations within the Content context.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType}

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @film_rel_slugs [
    "screened_at",
    "directed",
    "produced",
    "screenwrote",
    "acted_in",
    "composed_for",
    "shot",
    "edited",
    "exec_produced",
    "participated_in"
  ]

  def create(attrs) do
    title = Map.get(attrs, :title) || Map.get(attrs, "title")
    type = Map.get(attrs, :type) || Map.get(attrs, "type") || "Short Film"
    slug = Content.slugify(title || "untitled-film")

    fields =
      attrs
      |> Map.drop([:title, :type, "title", "type"])
      |> Enum.map(fn
        {k, v} when is_atom(k) -> {to_string(k), v}
        {k, v} -> {k, v}
      end)
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    %Entity{}
    |> Entity.changeset(%{
      type: type,
      identity: title,
      slug: slug,
      visible: true,
      fields: fields
    })
    |> Repo.insert()
  end

  def list_film_events do
    Repo.all(
      from e in Entity,
        where: e.type == "event",
        where:
          fragment("? ->> 'type' = 'screening'", e.fields) or
            fragment("? ->> 'type' = 'video'", e.fields) or
            fragment("? ->> 'type' = 'film'", e.fields),
        order_by: [
          desc: fragment("? ->> ?", e.fields, "date"),
          asc: fragment("? ->> ?", e.fields, "title")
        ]
    )
  end

  def attach_event(%Entity{} = film, %Entity{} = event) do
    rt = Repo.get_by!(RelationshipType, slug: "screened_at")

    %Relationship{}
    |> Relationship.changeset(%{
      relationship_type_id: rt.id,
      subject_id: film.id,
      object_id: event.id
    })
    |> Repo.insert()
  end

  def detach_event(%Entity{} = film, event_id) do
    rt = Repo.get_by!(RelationshipType, slug: "screened_at")

    Repo.delete_all(
      from r in Relationship,
        where:
          r.subject_id == ^film.id and r.object_id == ^event_id and
            r.relationship_type_id == ^rt.id
    )

    {:ok, :detached}
  end

  def list_linked_events(%Entity{} = film) do
    rt = Repo.get_by(RelationshipType, slug: "screened_at")

    if rt do
      Repo.all(
        from r in Relationship,
          where: r.subject_id == ^film.id and r.relationship_type_id == ^rt.id,
          preload: [:object, :relationship_type]
      )
    else
      []
    end
  end

  def list do
    Repo.all(
      from e in Entity,
        where: e.type in ^@film_types,
        order_by: [asc: fragment("? ->> ?", e.fields, "ref")]
    )
  end

  def get!(id), do: Repo.get!(Entity, id)

  def get_for_show!(id) do
    rt_ids =
      from rt in RelationshipType,
        where: rt.slug in ^@film_rel_slugs,
        select: rt.id

    rel_query =
      from r in Relationship,
        where: r.relationship_type_id in subquery(rt_ids),
        preload: [:object, :relationship_type]

    Repo.get!(Entity, id) |> Repo.preload(as_subject: rel_query)
  end

  def list_relationships(%Entity{} = film) do
    rt_ids =
      from rt in RelationshipType,
        where: rt.slug in ^@film_rel_slugs,
        select: rt.id

    Repo.all(
      from r in Relationship,
        where: r.subject_id == ^film.id and r.relationship_type_id in subquery(rt_ids),
        preload: [:object, :relationship_type],
        order_by: [asc: :relationship_type_id]
    )
  end

  def list_directors(%Entity{} = film) do
    rt = Repo.get_by(RelationshipType, slug: "directed")
    if rt, do: list_rels_by_type(film, rt.id), else: []
  end

  def update(%Entity{} = film, attrs) do
    current_fields = film.fields

    new_fields =
      Enum.reduce(
        [
          :ref,
          :runtime,
          :country,
          :log_line,
          :synopsis,
          :year,
          :dir_by,
          :sub_by,
          :trailer_url,
          :trailer_embed,
          :screening_copy_url
        ],
        current_fields,
        fn key, acc ->
          case Map.get(attrs, key) do
            nil -> acc
            value -> Map.put(acc, to_string(key), value)
          end
        end
      )

    identity = Map.get(attrs, :title) || film.identity
    type = Map.get(attrs, :type) || film.type

    Content.update_entity(film, %{
      identity: identity,
      type: type,
      visible: Map.get(attrs, :visible, film.visible),
      fields: new_fields
    })
  end

  def delete(%Entity{} = film) do
    Repo.delete_all(from r in Relationship, where: r.subject_id == ^film.id)
    Repo.delete_all(from r in Relationship, where: r.object_id == ^film.id)
    Content.delete_entity(film)
  end

  defp list_rels_by_type(film, rt_id) do
    Repo.all(
      from r in Relationship,
        where: r.subject_id == ^film.id and r.relationship_type_id == ^rt_id,
        preload: [:object]
    )
  end
end
