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
        [:title, :ref, :runtime, :country, :log_line, :synopsis, :year, :dir_by, :sub_by],
        current_fields,
        fn key, acc ->
          case Map.get(attrs, key) do
            nil -> acc
            value -> Map.put(acc, to_string(key), value)
          end
        end
      )

    identity = Map.get(attrs, :title) || film.identity

    Content.update_entity(film, %{
      identity: identity,
      visible: Map.get(attrs, :visible, film.visible),
      fields: new_fields
    })
  end

  def delete(%Entity{} = film) do
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
