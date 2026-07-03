defmodule MykonosBiennale.Content do
  @moduledoc """
  The Content context handles common entity, relationship, and media operations.

  Domain-specific operations are in:
  - `MykonosBiennale.Content.Biennale`
  - `MykonosBiennale.Content.Event`
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Workers.SearchReindex
  alias MykonosBiennale.Thumbnail

  ## Delegates - Biennale

  defdelegate list_biennales, to: MykonosBiennale.Content.Biennale, as: :list
  defdelegate get_biennale!(id), to: MykonosBiennale.Content.Biennale, as: :get!
  defdelegate get_biennale_by_year(year), to: MykonosBiennale.Content.Biennale, as: :get_by_year
  defdelegate create_biennale(attrs \\ %{}), to: MykonosBiennale.Content.Biennale, as: :create
  defdelegate update_biennale(entity, attrs), to: MykonosBiennale.Content.Biennale, as: :update
  defdelegate delete_biennale(entity), to: MykonosBiennale.Content.Biennale, as: :delete

  defdelegate change_biennale(entity, attrs \\ %{}),
    to: MykonosBiennale.Content.Biennale,
    as: :change

  ## Delegates - Event

  defdelegate list_events_for_biennale(year),
    to: MykonosBiennale.Content.Event,
    as: :list_for_biennale

  defdelegate list_events, to: MykonosBiennale.Content.Event, as: :list
  defdelegate list_events_for_admin, to: MykonosBiennale.Content.Event, as: :list_for_admin
  defdelegate get_event!(id), to: MykonosBiennale.Content.Event, as: :get!
  defdelegate get_event_for_admin!(id), to: MykonosBiennale.Content.Event, as: :get_for_admin!
  defdelegate create_event(attrs \\ %{}), to: MykonosBiennale.Content.Event, as: :create
  defdelegate update_event(entity, attrs), to: MykonosBiennale.Content.Event, as: :update
  defdelegate delete_event(entity), to: MykonosBiennale.Content.Event, as: :delete
  defdelegate change_event(entity, attrs \\ %{}), to: MykonosBiennale.Content.Event, as: :change

  ## Delegates - Participant

  defdelegate list_participants, to: MykonosBiennale.Content.Participant, as: :list
  defdelegate get_participant!(id), to: MykonosBiennale.Content.Participant, as: :get!

  defdelegate create_participant(attrs \\ %{}),
    to: MykonosBiennale.Content.Participant,
    as: :create

  defdelegate update_participant(entity, attrs),
    to: MykonosBiennale.Content.Participant,
    as: :update

  defdelegate delete_participant(entity), to: MykonosBiennale.Content.Participant, as: :delete

  defdelegate change_participant(entity, attrs \\ %{}),
    to: MykonosBiennale.Content.Participant,
    as: :change

  ## Delegates - Film

  defdelegate create_film(attrs \\ %{}), to: MykonosBiennale.Content.Film, as: :create
  defdelegate list_film_events, to: MykonosBiennale.Content.Film, as: :list_film_events

  defdelegate attach_event_to_film(entity, event),
    to: MykonosBiennale.Content.Film,
    as: :attach_event

  defdelegate detach_event_from_film(entity, event_id),
    to: MykonosBiennale.Content.Film,
    as: :detach_event

  defdelegate list_film_linked_events(entity),
    to: MykonosBiennale.Content.Film,
    as: :list_linked_events

  ## Delegates - Artwork

  defdelegate list_artworks, to: MykonosBiennale.Content.Artwork, as: :list
  defdelegate get_artwork!(id), to: MykonosBiennale.Content.Artwork, as: :get!
  defdelegate create_artwork(attrs \\ %{}), to: MykonosBiennale.Content.Artwork, as: :create
  defdelegate update_artwork(entity, attrs), to: MykonosBiennale.Content.Artwork, as: :update
  defdelegate delete_artwork(entity), to: MykonosBiennale.Content.Artwork, as: :delete

  defdelegate change_artwork(entity, attrs \\ %{}),
    to: MykonosBiennale.Content.Artwork,
    as: :change

  defdelegate get_artwork_for_admin!(id),
    to: MykonosBiennale.Content.Artwork,
    as: :get_for_admin!

  defdelegate list_artwork_linked_events(entity),
    to: MykonosBiennale.Content.Artwork,
    as: :list_linked_events

  defdelegate attach_event_to_artwork(entity, event),
    to: MykonosBiennale.Content.Artwork,
    as: :attach_event

  defdelegate detach_event_from_artwork(entity, event_id),
    to: MykonosBiennale.Content.Artwork,
    as: :detach_event

  defdelegate list_artwork_linked_participants(entity),
    to: MykonosBiennale.Content.Artwork,
    as: :list_linked_participants

  defdelegate attach_participant_to_artwork(entity, participant, role),
    to: MykonosBiennale.Content.Artwork,
    as: :attach_participant

  defdelegate detach_participant_from_artwork(entity, participant_id),
    to: MykonosBiennale.Content.Artwork,
    as: :detach_participant

  defdelegate artwork_relationship_name_for_type(type),
    to: MykonosBiennale.Content.Artwork,
    as: :relationship_name_for_type

  ## Delegates - RelationshipType

  defdelegate list_relationship_types,
    to: MykonosBiennale.Content.RelationshipType,
    as: :list

  defdelegate get_relationship_type!(id),
    to: MykonosBiennale.Content.RelationshipType,
    as: :get!

  defdelegate create_relationship_type(attrs \\ %{}),
    to: MykonosBiennale.Content.RelationshipType,
    as: :create

  defdelegate update_relationship_type(entity, attrs),
    to: MykonosBiennale.Content.RelationshipType,
    as: :update

  defdelegate delete_relationship_type(entity),
    to: MykonosBiennale.Content.RelationshipType,
    as: :delete

  ## Delegates - Project

  defdelegate list_projects, to: MykonosBiennale.Content.Project, as: :list

  defdelegate list_projects_for_biennale(year),
    to: MykonosBiennale.Content.Project,
    as: :list_for_biennale

  defdelegate get_project!(id), to: MykonosBiennale.Content.Project, as: :get!

  defdelegate list_event_media_for_project(project),
    to: MykonosBiennale.Content.Project,
    as: :list_event_media

  defdelegate create_project(attrs \\ %{}), to: MykonosBiennale.Content.Project, as: :create
  defdelegate update_project(entity, attrs), to: MykonosBiennale.Content.Project, as: :update
  defdelegate delete_project(entity), to: MykonosBiennale.Content.Project, as: :delete

  defdelegate change_project(entity, attrs \\ %{}),
    to: MykonosBiennale.Content.Project,
    as: :change

  ## Entities

  @doc """
  Returns the list of entities.
  """
  def list_entities do
    Repo.all(from e in Entity, order_by: e.inserted_at)
  end

  @doc """
  Returns the list of visible entities.
  """
  def list_visible_entities do
    Repo.all(from e in Entity, where: e.visible == true, order_by: e.inserted_at)
  end

  @doc """
  Gets a single entity.
  """
  def get_entity!(id) do
    Repo.get!(Entity, id) |> Repo.preload([:as_subject, :as_object])
  end

  @doc """
  Gets an entity by slug.
  """
  def get_entity_by_slug(slug) do
    Repo.get_by(Entity, slug: slug) |> Repo.preload([:as_subject, :as_object])
  end

  @doc """
  Creates an entity.
  """
  def create_entity(attrs \\ %{}) do
    %Entity{}
    |> Entity.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(&SearchReindex.enqueue_entity(&1.id))
  end

  @doc """
  Updates an entity.
  """
  def update_entity(%Entity{} = entity, attrs) do
    entity
    |> Entity.changeset(attrs)
    |> Repo.update()
    |> tap_ok(&SearchReindex.enqueue_entity_cascade(&1.id))
  end

  @doc """
  Deletes an entity.
  """
  def delete_entity(%Entity{} = entity) do
    neighbor_ids = neighbor_ids_of(entity.id)

    case Repo.delete(entity) do
      {:ok, deleted} = ok ->
        if neighbor_ids != [], do: SearchReindex.enqueue_ids_cascade(neighbor_ids)
        _ = deleted
        ok

      other ->
        other
    end
  end

  defp neighbor_ids_of(entity_id) do
    Repo.all(
      from r in Relationship,
        where: r.subject_id == ^entity_id or r.object_id == ^entity_id,
        select:
          fragment(
            "CASE WHEN ? = ? THEN ? ELSE ? END",
            r.subject_id,
            ^entity_id,
            r.object_id,
            r.subject_id
          )
    )
    |> Enum.uniq()
  end

  defp tap_ok({:ok, value} = result, fun) do
    _ = fun.(value)
    result
  end

  defp tap_ok(other, _fun), do: other

  defp enqueue_media_process(%Media{source_type: "upload"} = media) do
    MykonosBiennale.Workers.MediaProcess.enqueue_all(media.id)
  end

  defp enqueue_media_process(_media), do: :ok

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking entity changes.
  """
  def change_entity(%Entity{} = entity, attrs \\ %{}) do
    Entity.changeset(entity, attrs)
  end

  ## Relationships

  @doc """
  Returns the list of relationships.
  """
  def list_relationships do
    Repo.all(from r in Relationship, preload: [:subject, :object, :relationship_type])
  end

  @doc """
  Gets a single relationship.
  """
  def get_relationship!(id) do
    Repo.get!(Relationship, id) |> Repo.preload([:subject, :object, :relationship_type])
  end

  @doc """
  Gets or creates a RelationshipType by slug and label.
  """
  def ensure_relationship_type!(slug, label) do
    case Repo.get_by(RelationshipType, slug: slug) do
      %RelationshipType{} = rt ->
        rt

      nil ->
        {:ok, rt} =
          %RelationshipType{}
          |> RelationshipType.changeset(%{slug: slug, label: label})
          |> Repo.insert()

        rt
    end
  end

  @doc """
  Creates a relationship with a relationship_type identified by slug.
  Pass `slug` and `label` (or just `slug` if the type already exists).
  """
  def create_relationship(attrs \\ %{}) do
    {slug, rest} = Map.pop(attrs, :slug) || Map.pop(attrs, "slug")
    {label, rest} = Map.pop(rest, :label) || Map.pop(rest, "label")
    {name, rest} = Map.pop(rest, :name) || Map.pop(rest, "name")

    label = label || name || slug

    rt = ensure_relationship_type!(slug, label)

    attrs = Map.put(rest, :relationship_type_id, rt.id)

    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(&enqueue_relationship_endpoints/1)
  end

  @doc """
  Updates a relationship.
  """
  def update_relationship(%Relationship{} = relationship, attrs) do
    old_ids = [relationship.subject_id, relationship.object_id]

    relationship
    |> Relationship.changeset(attrs)
    |> Repo.update()
    |> tap_ok(fn updated ->
      ids = Enum.uniq(old_ids ++ [updated.subject_id, updated.object_id])
      SearchReindex.enqueue_ids_cascade(ids)
    end)
  end

  @doc """
  Deletes a relationship.
  """
  def delete_relationship(%Relationship{} = relationship) do
    ids = [relationship.subject_id, relationship.object_id]

    case Repo.delete(relationship) do
      {:ok, _} = ok ->
        SearchReindex.enqueue_ids_cascade(ids)
        ok

      other ->
        other
    end
  end

  defp enqueue_relationship_endpoints(%Relationship{subject_id: s, object_id: o}) do
    SearchReindex.enqueue_ids_cascade([s, o])
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking relationship changes.
  """
  def change_relationship(%Relationship{} = relationship, attrs \\ %{}) do
    Relationship.changeset(relationship, attrs)
  end

  ## Media

  @doc """
  Returns the list of media.
  """
  def list_media do
    Repo.all(from m in Media, order_by: [desc: m.inserted_at])
  end

  @doc """
  Returns a paginated list of media matching an optional search pattern.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - field to sort by (`:inserted_at`, `:caption`). Default `:inserted_at`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:desc`.
  """
  def list_media_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    order = media_sort_clause(sort_by, sort_dir)
    base_query = from(m in Media, order_by: ^order)

    filtered_query =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        from(m in base_query,
          where: not is_nil(m.search_index) and like(m.search_index, ^pattern)
        )
      else
        base_query
      end

    items =
      from(m in filtered_query, limit: ^per_page, offset: ^offset)
      |> Repo.all()

    total_count = filtered_query |> exclude(:order_by) |> Repo.aggregate(:count, :id)

    {items, total_count}
  end

  defp media_sort_clause(:inserted_at, :asc), do: [asc: :inserted_at]
  defp media_sort_clause(:inserted_at, :desc), do: [desc: :inserted_at]
  defp media_sort_clause(:caption, :asc), do: [asc: :caption]
  defp media_sort_clause(:caption, :desc), do: [desc: :caption]
  defp media_sort_clause(_, _), do: [desc: :inserted_at]

  @doc """
  Returns a paginated list of artworks matching an optional search pattern.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - `:title`, `:date`. Default `:date`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:desc`.
  """
  def list_artworks_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    sort_by = Keyword.get(opts, :sort_by, :date)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    order = entity_sort_clause("artwork", sort_by, sort_dir)
    base_query = from(e in Entity, where: e.type == "artwork", order_by: ^order)

    filtered_query =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        from(e in base_query,
          where: not is_nil(e.search_index) and like(e.search_index, ^pattern)
        )
      else
        base_query
      end

    items = from(e in filtered_query, limit: ^per_page, offset: ^offset) |> Repo.all()
    total_count = filtered_query |> exclude(:order_by) |> Repo.aggregate(:count, :id)
    {items, total_count}
  end

  @doc """
  Returns a paginated list of participants matching an optional search pattern.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - `:name`, `:country`, `:email`. Default `:name`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:asc`.
  """
  def list_participants_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    sort_by = Keyword.get(opts, :sort_by, :name)
    sort_dir = Keyword.get(opts, :sort_dir, :asc)

    order = entity_sort_clause("participant", sort_by, sort_dir)
    base_query = from(e in Entity, where: e.type == "participant", order_by: ^order)

    filtered_query =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        from(e in base_query,
          where: not is_nil(e.search_index) and like(e.search_index, ^pattern)
        )
      else
        base_query
      end

    items = from(e in filtered_query, limit: ^per_page, offset: ^offset) |> Repo.all()
    total_count = filtered_query |> exclude(:order_by) |> Repo.aggregate(:count, :id)
    {items, total_count}
  end

  @doc """
  Returns a paginated list of films matching an optional search pattern.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - `:ref`, `:title`, `:type`. Default `:ref`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:asc`.
  """
  def list_films_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    film_types = ["Short Film", "Video", "Dance", "Animation", "Documentary"]
    sort_by = Keyword.get(opts, :sort_by, :ref)
    sort_dir = Keyword.get(opts, :sort_dir, :asc)

    order = entity_sort_clause("film", sort_by, sort_dir)
    base_query = from(e in Entity, where: e.type in ^film_types, order_by: ^order)

    filtered_query =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        from(e in base_query,
          where: not is_nil(e.search_index) and like(e.search_index, ^pattern)
        )
      else
        base_query
      end

    items = from(e in filtered_query, limit: ^per_page, offset: ^offset) |> Repo.all()
    total_count = filtered_query |> exclude(:order_by) |> Repo.aggregate(:count, :id)
    {items, total_count}
  end

  @doc """
  Returns a paginated list of events for the admin view.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - `:title`, `:date`, `:type`. Default `:date`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:asc`.
  """
  def list_events_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    sort_by = Keyword.get(opts, :sort_by, :date)
    sort_dir = Keyword.get(opts, :sort_dir, :asc)

    order = entity_sort_clause("event", sort_by, sort_dir)
    base_query = from(e in Entity, where: e.type == "event", order_by: ^order)

    filtered_query =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        from(e in base_query,
          where: not is_nil(e.search_index) and like(e.search_index, ^pattern)
        )
      else
        base_query
      end

    rt_ids =
      from(rt in RelationshipType,
        where: rt.slug in ^["biennale_event", "event_festival", "event_project"],
        select: rt.id
      )

    rel_query =
      from(r in Relationship,
        where: r.relationship_type_id in subquery(rt_ids),
        preload: [:object, :relationship_type]
      )

    items =
      from(e in filtered_query, limit: ^per_page, offset: ^offset)
      |> Repo.all()
      |> Repo.preload(as_subject: rel_query)

    total_count = filtered_query |> exclude(:order_by) |> Repo.aggregate(:count, :id)
    {items, total_count}
  end

  @doc """
  Returns a paginated list of relationships matching an optional search pattern.
  Returns `{items, total_count}`.

  Options:
    - `:sort_by` - `:inserted_at`, `:type`. Default `:inserted_at`.
    - `:sort_dir` - `:asc` or `:desc`. Default `:desc`.
  """
  def list_relationships_paginated(page \\ 1, per_page \\ 24, search \\ "", opts \\ []) do
    offset = (page - 1) * per_page
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    order = relationship_sort_clause(sort_by, sort_dir)

    base_query =
      from(r in Relationship,
        preload: [:subject, :object, :relationship_type],
        order_by: ^order
      )

    {items, total_count} =
      if search != "" do
        pattern = MykonosBiennale.Search.entity_search_pattern(search)

        filtered =
          from(r in Relationship,
            join: s in Entity,
            on: s.id == r.subject_id,
            join: o in Entity,
            on: o.id == r.object_id,
            join: rt in RelationshipType,
            on: rt.id == r.relationship_type_id,
            where:
              like(s.search_index, ^pattern) or
                like(o.search_index, ^pattern) or
                like(rt.slug, ^pattern) or
                like(rt.label, ^pattern),
            preload: [:subject, :object, :relationship_type],
            order_by: ^order
          )

        count_query =
          from(r in Relationship,
            join: s in Entity,
            on: s.id == r.subject_id,
            join: o in Entity,
            on: o.id == r.object_id,
            join: rt in RelationshipType,
            on: rt.id == r.relationship_type_id,
            where:
              like(s.search_index, ^pattern) or
                like(o.search_index, ^pattern) or
                like(rt.slug, ^pattern) or
                like(rt.label, ^pattern),
            select: count(r.id)
          )

        items = from(r in filtered, limit: ^per_page, offset: ^offset) |> Repo.all()
        total_count = Repo.one(count_query)
        {items, total_count}
      else
        items = from(r in base_query, limit: ^per_page, offset: ^offset) |> Repo.all()
        total_count = Repo.one(from(r in Relationship, select: count(r.id)))
        {items, total_count}
      end

    {items, total_count}
  end

  defp relationship_sort_clause(:inserted_at, :asc), do: [asc: :inserted_at]
  defp relationship_sort_clause(:inserted_at, :desc), do: [desc: :inserted_at]
  defp relationship_sort_clause(:type, :asc), do: [asc: :relationship_type_id]
  defp relationship_sort_clause(:type, :desc), do: [desc: :relationship_type_id]
  defp relationship_sort_clause(_, _), do: [desc: :inserted_at]

  defp entity_sort_clause("artwork", :title, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "title"))}]

  defp entity_sort_clause("artwork", :date, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "date"))}]

  defp entity_sort_clause("participant", :name, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "last_name"))}]

  defp entity_sort_clause("participant", :country, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "country"))}]

  defp entity_sort_clause("participant", :email, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "email"))}]

  defp entity_sort_clause("film", :ref, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "ref"))}]

  defp entity_sort_clause("film", :title, dir), do: [{dir, dynamic([e], e.identity)}]
  defp entity_sort_clause("film", :type, dir), do: [{dir, dynamic([e], e.type)}]

  defp entity_sort_clause("event", :title, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "title"))}]

  defp entity_sort_clause("event", :date, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "date"))}]

  defp entity_sort_clause("event", :type, dir),
    do: [{dir, dynamic([e], fragment("? ->> ?", e.fields, "type"))}]

  defp entity_sort_clause("artwork", _, _),
    do: [desc: dynamic([e], fragment("? ->> ?", e.fields, "date"))]

  defp entity_sort_clause("participant", _, _),
    do: [asc: dynamic([e], fragment("? ->> ?", e.fields, "last_name"))]

  defp entity_sort_clause("film", _, _),
    do: [asc: dynamic([e], fragment("? ->> ?", e.fields, "ref"))]

  defp entity_sort_clause("event", _, _),
    do: [asc: dynamic([e], fragment("? ->> ?", e.fields, "date"))]

  @doc """
  Gets a single media.
  """
  def get_media!(id), do: Repo.get!(Media, id)

  def get_media_by_slug(slug) do
    Repo.get_by(Media, slug: slug)
  end

  @doc """
  Creates a media.
  """
  def create_media(attrs \\ %{}) do
    %Media{}
    |> Media.changeset(attrs)
    |> Repo.insert()
    |> set_slug_if_needed()
    |> tap_ok(&SearchReindex.enqueue_media(&1.id))
    |> tap_ok(&enqueue_media_process(&1))
  end

  defp set_slug_if_needed({:ok, %Media{slug: nil, id: id} = media}) when not is_nil(id) do
    slug = MykonosBiennale.MediaSlug.generate(id, media.caption, media.original_name)

    media
    |> Media.changeset(%{slug: slug})
    |> Repo.update()
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp set_slug_if_needed(result), do: result

  @doc """
  Updates a media.
  """
  def update_media(%Media{} = media, attrs) do
    if media.slug && media.source_type == "upload" do
      Thumbnail.invalidate_slug_cache(media.slug)
    end

    result =
      media
      |> Media.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        if updated.slug && updated.source_type == "upload" do
          MykonosBiennale.Workers.MediaProcess.enqueue_all(updated.id)
        end

        SearchReindex.enqueue_media(updated.id)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc """
  Deletes a media.
  """
  def delete_media(%Media{} = media) do
    if media.slug && media.source_type == "upload" do
      Thumbnail.invalidate_slug_cache(media.slug)
    end

    Repo.delete(media)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking media changes.
  """
  def change_media(%Media{} = media, attrs \\ %{}) do
    Media.changeset(media, attrs)
  end

  ## Entity-Media Relationships

  @doc """
  Attaches media to an entity with optional position and metadata.
  """
  def attach_media_to_entity(%Entity{} = entity, %Media{} = media, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    if Repo.get_by(EntityMedia, entity_id: entity.id, media_id: media.id) do
      {:error, "Media already attached to this entity"}
    else
      position =
        case Keyword.fetch(opts, :position) do
          {:ok, pos} ->
            pos

          :error ->
            Repo.one(
              from em in EntityMedia,
                where: em.entity_id == ^entity.id,
                select: coalesce(max(em.position), -1)
            ) + 1
        end

      %EntityMedia{}
      |> EntityMedia.changeset(%{
        entity_id: entity.id,
        media_id: media.id,
        position: position,
        metadata: metadata
      })
      |> Repo.insert()
      |> case do
        {:ok, _} ->
          SearchReindex.enqueue_media(media.id)
          {:ok, :attached}

        {:error, cs} ->
          {:error, cs}
      end
    end
  end

  @doc """
  Detaches media from an entity.
  """
  def detach_media_from_entity(%Entity{} = entity, %Media{} = media) do
    Repo.delete_all(
      from em in EntityMedia, where: em.entity_id == ^entity.id and em.media_id == ^media.id
    )

    SearchReindex.enqueue_media(media.id)
    {:ok, :detached}
  end

  @doc """
  Lists all media attached to an entity, ordered by position.
  """
  def list_media_for_entity(%Entity{id: entity_id}) do
    Repo.all(
      from m in Media,
        join: em in "entity_media",
        on: em.media_id == m.id,
        where: em.entity_id == ^entity_id,
        order_by: em.position,
        select: m
    )
  end

  @doc """
  Lists entity-media links for an entity, including join metadata (position + metadata) and media.
  """
  def list_entity_media_links_for_entity(%Entity{id: entity_id}) do
    Repo.all(
      from em in EntityMedia,
        where: em.entity_id == ^entity_id,
        order_by: em.position,
        preload: [:media]
    )
  end

  @doc """
  Updates link metadata for a single media item attached to an entity.
  """
  def update_entity_media_link(%Entity{id: entity_id}, %Media{id: media_id}, metadata)
      when is_map(metadata) do
    Repo.update_all(
      from(em in EntityMedia, where: em.entity_id == ^entity_id and em.media_id == ^media_id),
      set: [metadata: metadata, updated_at: NaiveDateTime.utc_now()]
    )

    {:ok, :updated}
  end

  @doc """
  Reorders media for an entity based on a list of media IDs.
  """
  def reorder_entity_media(%Entity{id: entity_id}, media_ids) when is_list(media_ids) do
    media_ids
    |> Enum.with_index()
    |> Enum.each(fn {media_id, position} ->
      Repo.update_all(
        from(em in "entity_media",
          where: em.entity_id == ^entity_id and em.media_id == ^media_id
        ),
        set: [position: position]
      )
    end)

    {:ok, :reordered}
  end

  @doc """
  Slugifies a string for use in URLs/slugs.
  """
  def slugify(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim_leading("-")
    |> String.trim_trailing("-")
  end
end
