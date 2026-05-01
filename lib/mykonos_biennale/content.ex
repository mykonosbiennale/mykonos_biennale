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
  alias MykonosBiennale.Content.{Entity, Relationship, Media, EntityMedia}

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
  end

  @doc """
  Updates an entity.
  """
  def update_entity(%Entity{} = entity, attrs) do
    entity
    |> Entity.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an entity.
  """
  def delete_entity(%Entity{} = entity) do
    Repo.delete(entity)
  end

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
    Repo.all(from r in Relationship, preload: [:subject, :object])
  end

  @doc """
  Gets a single relationship.
  """
  def get_relationship!(id) do
    Repo.get!(Relationship, id) |> Repo.preload([:subject, :object])
  end

  @doc """
  Creates a relationship.
  """
  def create_relationship(attrs \\ %{}) do
    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a relationship.
  """
  def update_relationship(%Relationship{} = relationship, attrs) do
    relationship
    |> Relationship.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a relationship.
  """
  def delete_relationship(%Relationship{} = relationship) do
    Repo.delete(relationship)
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
  end

  @doc """
  Updates a media.
  """
  def update_media(%Media{} = media, attrs) do
    media
    |> Media.changeset(attrs)
    |> Repo.update()
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
        {:ok, _} -> {:ok, :attached}
        {:error, cs} -> {:error, cs}
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
