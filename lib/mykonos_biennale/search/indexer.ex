defmodule MykonosBiennale.Search.Indexer do
  @moduledoc """
  Builds and persists a field-scoped, transliterated search index string for
  entities and media.

  The index string is a single space-separated token stream where tokens are
  prefixed by their section name, e.g.

      identity:venieri rel.creator:venieri λυδια βενιερη lydia venieri rel.event:garden of mysteries

  Plain `LIKE '%term%'` works as a general substring search; an advanced
  filter UI can later target a specific section with `LIKE '%rel.creator:%term%'`.

  Both Greek and Latin transliterations are concatenated for every token via
  `MykonosBiennale.Search.Transliterate.normalize/1`.

  ## Sections

    * `identity:`            entity.identity
    * `type:`                entity.type
    * `slug:`                entity.slug
    * `field.<key>:`         each value in `entity.fields`
    * `rel.<role>:`          one entry per outgoing relationship
                             (e.g. `rel.creator:`, `rel.event:`, `rel.biennale_year:`)
    * `caption:` / `alt:`    media-only

  Outgoing relationships are role-mapped per the table below. Reverse direction
  links are also indexed so a participant gets `rel.in_artwork:` etc.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Search.Transliterate

  # Subject -> Object: how to label the relationship in the subject's index.
  @rel_role_for_subject %{
    "artwork_event" => "event",
    "artwork_participant" => "creator",
    "screened_at" => "event",
    "directed" => "person",
    "produced" => "person",
    "screenwrote" => "person",
    "acted_in" => "person",
    "composed_for" => "person",
    "shot" => "person",
    "edited" => "person",
    "exec_produced" => "person",
    "participated_in" => "person",
    "biennale_event" => "biennale",
    "event_festival" => "festival",
    "event_project" => "project"
  }

  # Object -> Subject: how to label the inverse for the object's index.
  @rel_role_for_object %{
    "artwork_event" => "in_artwork",
    "artwork_participant" => "in_artwork",
    "screened_at" => "in_film",
    "directed" => "directed_film",
    "produced" => "produced_film",
    "screenwrote" => "screenwrote_film",
    "acted_in" => "acted_in_film",
    "composed_for" => "composed_for_film",
    "shot" => "shot_film",
    "edited" => "edited_film",
    "exec_produced" => "exec_produced_film",
    "participated_in" => "in_film",
    "biennale_event" => "in_biennale",
    "event_festival" => "in_festival",
    "event_project" => "in_project"
  }

  # =====================================================================
  # Public API
  # =====================================================================

  @doc """
  Reindex a single entity by id. Returns `{:ok, entity}` or `{:error, :not_found}`.
  """
  def index_entity(id) when is_integer(id) do
    case Repo.get(Entity, id) do
      nil ->
        {:error, :not_found}

      %Entity{} = entity ->
        index = build_entity_index(entity)
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.update_all(
          from(e in Entity, where: e.id == ^id),
          set: [search_index: index, search_indexed_at: now]
        )

        {:ok, entity}
    end
  end

  @doc """
  Reindex a single media by id. Returns `{:ok, media}` or `{:error, :not_found}`.

  Media inherits the full search_index of every entity it is attached to.
  """
  def index_media(id) when is_integer(id) do
    case Repo.get(Media, id) do
      nil ->
        {:error, :not_found}

      %Media{} = media ->
        index = build_media_index(media)
        now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

        Repo.update_all(
          from(m in Media, where: m.id == ^id),
          set: [search_index: index, search_indexed_at: now]
        )

        {:ok, media}
    end
  end

  @doc """
  Returns the index string for an entity without persisting. Useful for tests.
  """
  def build_entity_index(%Entity{} = entity) do
    entity = preload_for_index(entity)

    [
      section("identity", entity.identity),
      section("type", entity.type),
      section("slug", entity.slug),
      fields_sections(entity.fields),
      outgoing_relationship_sections(entity),
      incoming_relationship_sections(entity),
      biennale_year_2hop(entity)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == "" or is_nil(&1)))
    |> Enum.join(" ")
  end

  @doc """
  Returns the index string for a media without persisting.

  Media inherits each linked entity's `search_index` verbatim, plus its own
  caption/alt/mime/metadata.
  """
  def build_media_index(%Media{} = media) do
    linked = linked_entities_with_index(media.id)

    [
      section("caption", media.caption),
      section("alt", media.alt_text),
      section("mime", media.mime_type),
      metadata_sections(media.metadata),
      Enum.map(linked, fn %{search_index: idx} -> idx || "" end)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == "" or is_nil(&1)))
    |> Enum.join(" ")
  end

  @doc """
  Normalize a search query the same way we normalize indexed text. Use this
  when constructing the SQL `LIKE` pattern.
  """
  def normalize_query(term) when is_binary(term) do
    Transliterate.normalize(term)
  end

  def normalize_query(term), do: normalize_query(to_string(term || ""))

  # =====================================================================
  # Private helpers
  # =====================================================================

  defp preload_for_index(%Entity{} = entity) do
    Repo.preload(entity,
      as_subject: from(r in Relationship, preload: [:relationship_type, :object]),
      as_object: from(r in Relationship, preload: [:relationship_type, :subject])
    )
  end

  defp section(_label, nil), do: ""
  defp section(_label, ""), do: ""

  defp section(label, value) when is_binary(value) do
    "#{label}:#{Transliterate.normalize(value)}"
  end

  defp section(label, value), do: section(label, to_string(value))

  # Field keys we never want indexed (import metadata, slugs, etc.)
  @ignored_field_keys ~w(import_model import_pk import_slug import_photo_url original_record leader)

  defp fields_sections(fields) when is_map(fields) do
    fields
    |> Enum.reject(fn {k, _v} -> to_string(k) in @ignored_field_keys end)
    |> Enum.map(fn {k, v} -> field_section(k, v) end)
  end

  defp fields_sections(_), do: []

  defp field_section(_k, nil), do: ""
  defp field_section(_k, ""), do: ""
  defp field_section(_k, []), do: ""

  defp field_section(k, list) when is_list(list) do
    list |> Enum.map(&field_section(k, &1)) |> Enum.reject(&(&1 == ""))
  end

  defp field_section(k, map) when is_map(map) do
    map |> Enum.map(fn {sk, sv} -> field_section("#{k}.#{sk}", sv) end) |> Enum.reject(&(&1 == ""))
  end

  defp field_section(k, v), do: section("field.#{k}", v)

  defp outgoing_relationship_sections(%Entity{as_subject: rels}) when is_list(rels) do
    Enum.flat_map(rels, fn r ->
      slug = relationship_slug(r)
      role = Map.get(@rel_role_for_subject, slug, slug)
      build_rel_sections("rel.#{role}", r, r.object, slug)
    end)
  end

  defp outgoing_relationship_sections(_), do: []

  defp incoming_relationship_sections(%Entity{as_object: rels}) when is_list(rels) do
    Enum.flat_map(rels, fn r ->
      slug = relationship_slug(r)
      role = Map.get(@rel_role_for_object, slug, "in_#{slug}")
      build_rel_sections("rel.#{role}", r, r.subject, slug)
    end)
  end

  defp incoming_relationship_sections(_), do: []

  defp build_rel_sections(prefix, %Relationship{} = r, %Entity{} = neighbor, _slug) do
    [
      neighbor_label_section(prefix, neighbor),
      neighbor_extras_section(prefix, neighbor),
      relationship_field_section(prefix, r, "role"),
      relationship_field_section(prefix, r, "roles")
    ]
  end

  defp build_rel_sections(_prefix, _r, _neighbor, _slug), do: []

  defp neighbor_label_section(prefix, %Entity{identity: identity}) when is_binary(identity) and identity != "" do
    section(prefix, identity)
  end

  defp neighbor_label_section(prefix, %Entity{fields: fields}) when is_map(fields) do
    case Map.get(fields, "name") || compose_name(fields) do
      nil -> ""
      "" -> ""
      name -> section(prefix, name)
    end
  end

  defp neighbor_label_section(_prefix, _), do: ""

  defp compose_name(fields) do
    first = Map.get(fields, "first_name", "") || ""
    last = Map.get(fields, "last_name", "") || ""

    case String.trim("#{first} #{last}") do
      "" -> nil
      s -> s
    end
  end

  defp neighbor_extras_section(prefix, %Entity{fields: fields}) when is_map(fields) do
    [
      neighbor_field(prefix, fields, "title"),
      neighbor_field(prefix, fields, "date"),
      neighbor_field(prefix, fields, "year"),
      neighbor_field(prefix, fields, "country"),
      neighbor_field(prefix, fields, "ref")
    ]
  end

  defp neighbor_extras_section(_prefix, _), do: []

  defp neighbor_field(prefix, fields, key) do
    case Map.get(fields, key) do
      nil -> ""
      "" -> ""
      v -> section(prefix, v)
    end
  end

  defp relationship_field_section(_prefix, %Relationship{fields: nil}, _key), do: ""

  defp relationship_field_section(prefix, %Relationship{fields: fields}, key) when is_map(fields) do
    case Map.get(fields, key) do
      nil -> ""
      "" -> ""
      v when is_list(v) -> section(prefix, Enum.join(v, " "))
      v -> section(prefix, v)
    end
  end

  defp relationship_field_section(_prefix, _, _), do: ""

  defp relationship_slug(%Relationship{relationship_type: %RelationshipType{slug: slug}}), do: slug
  defp relationship_slug(_), do: nil

  # 2-hop: for entities whose direct events are linked to a biennale, expose the biennale year.
  defp biennale_year_2hop(%Entity{type: type} = entity) when type in ["artwork", "Short Film", "Video", "Dance", "Animation", "Documentary"] do
    biennale_years = list_biennale_years_via_events(entity.id)
    Enum.map(biennale_years, &section("rel.biennale_year", &1))
  end

  defp biennale_year_2hop(%Entity{type: "event"} = entity) do
    biennale_years = list_biennale_years_directly(entity.id)
    Enum.map(biennale_years, &section("rel.biennale_year", &1))
  end

  defp biennale_year_2hop(_), do: []

  defp list_biennale_years_via_events(entity_id) do
    Repo.all(
      from b in Entity,
        join: r2 in Relationship, on: r2.object_id == b.id,
        join: rt2 in RelationshipType, on: rt2.id == r2.relationship_type_id,
        join: evt in Entity, on: evt.id == r2.subject_id,
        join: r1 in Relationship, on: r1.object_id == evt.id,
        where:
          r1.subject_id == ^entity_id and rt2.slug == "biennale_event" and b.type == "biennale",
        distinct: true,
        select: fragment("? ->> 'year'", b.fields)
    )
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp list_biennale_years_directly(event_id) do
    Repo.all(
      from b in Entity,
        join: r in Relationship, on: r.object_id == b.id,
        join: rt in RelationshipType, on: rt.id == r.relationship_type_id,
        where: r.subject_id == ^event_id and rt.slug == "biennale_event" and b.type == "biennale",
        distinct: true,
        select: fragment("? ->> 'year'", b.fields)
    )
    |> Enum.reject(&(&1 in [nil, ""]))
  end

  defp metadata_sections(metadata) when is_map(metadata) do
    Enum.map(metadata, fn {k, v} -> field_section("meta.#{k}", v) end)
  end

  defp metadata_sections(_), do: []

  defp linked_entities_with_index(media_id) do
    Repo.all(
      from e in Entity,
        join: em in EntityMedia, on: em.entity_id == e.id,
        where: em.media_id == ^media_id,
        select: %{id: e.id, search_index: e.search_index}
    )
  end
end
