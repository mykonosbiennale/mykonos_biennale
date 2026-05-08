defmodule MykonosBiennale.Content do
  @moduledoc """
  The Content context handles common entity, relationship, and media operations.

  Domain-specific operations are in:
  - `MykonosBiennale.Content.Biennale`
  - `MykonosBiennale.Content.Event`
  - `MykonosBiennale.Content.Festival`
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Relationship, RelationshipType, Media, EntityMedia}
  alias MykonosBiennale.Workers.SearchReindex

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

  ## Delegates - Festival

  defdelegate list_festivals, to: MykonosBiennale.Content.Festival, as: :list
  defdelegate get_festival!(id), to: MykonosBiennale.Content.Festival, as: :get!
  defdelegate create_festival(attrs \\ %{}), to: MykonosBiennale.Content.Festival, as: :create
  defdelegate update_festival(entity, attrs), to: MykonosBiennale.Content.Festival, as: :update
  defdelegate delete_festival(entity), to: MykonosBiennale.Content.Festival, as: :delete

  defdelegate change_festival(entity, attrs \\ %{}),
    to: MykonosBiennale.Content.Festival,
    as: :change

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
  defdelegate get_project!(id), to: MykonosBiennale.Content.Project, as: :get!
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
  Gets a single media.
  """
  def get_media!(id), do: Repo.get!(Media, id)

  @doc """
  Creates a media.
  """
  def create_media(attrs \\ %{}) do
    %Media{}
    |> Media.changeset(attrs)
    |> Repo.insert()
    |> tap_ok(&SearchReindex.enqueue_media(&1.id))
  end

  @doc """
  Updates a media.
  """
  def update_media(%Media{} = media, attrs) do
    media
    |> Media.changeset(attrs)
    |> Repo.update()
    |> tap_ok(&SearchReindex.enqueue_media(&1.id))
  end

  @doc """
  Deletes a media.
  """
  def delete_media(%Media{} = media) do
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
