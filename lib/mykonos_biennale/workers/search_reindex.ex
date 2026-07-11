defmodule MykonosBiennale.Workers.SearchReindex do
  @moduledoc """
  Oban worker that rebuilds the `search_index` column for entities and media.

  ## Job kinds

    * `%{"kind" => "entity", "id" => id}` — reindex a single entity
    * `%{"kind" => "media",  "id" => id}` — reindex a single media row
    * `%{"kind" => "entity_cascade", "id" => id}` — reindex the entity, then
      every directly-related entity (1 hop) and every media attached to any
      of them. Used after a write that may have changed neighbors' index.
    * `%{"kind" => "ids_cascade", "ids" => [id1, id2, ...]}` — reindex an
      explicit list of entity ids and any media attached to them. Used when
      a relationship is deleted and we already know both endpoints, or when
      an entity is being deleted and we want to reindex its former neighbors.

  Jobs are uniqued on their args within a 5s window so duplicate enqueues
  during a burst of writes coalesce.
  """
  use Oban.Worker,
    queue: :search,
    unique: [period: 5, keys: [:args]]

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Relationship, EntityMedia}
  alias MykonosBiennale.Search.Indexer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"kind" => "entity", "id" => id}}) do
    case Indexer.index_entity(id) do
      {:ok, _} -> :ok
      {:error, :not_found} -> :ok
    end
  end

  def perform(%Oban.Job{args: %{"kind" => "media", "id" => id}}) do
    case Indexer.index_media(id) do
      {:ok, _} -> :ok
      {:error, :not_found} -> :ok
    end
  end

  def perform(%Oban.Job{args: %{"kind" => "entity_cascade", "id" => id}}) do
    Indexer.index_entity(id)
    neighbor_ids = neighbors_of(id)
    Enum.each(neighbor_ids, &Indexer.index_entity/1)

    media_ids = media_for_entities([id | neighbor_ids])
    Enum.each(media_ids, &Indexer.index_media/1)
    :ok
  end

  def perform(%Oban.Job{args: %{"kind" => "ids_cascade", "ids" => ids}}) when is_list(ids) do
    Enum.each(ids, &Indexer.index_entity/1)

    media_ids = media_for_entities(ids)
    Enum.each(media_ids, &Indexer.index_media/1)
    :ok
  end

  # =====================================================================
  # Public enqueue helpers
  # =====================================================================

  @doc "Enqueue a reindex of a single entity."
  def enqueue_entity(id) when is_integer(id) do
    %{kind: "entity", id: id} |> __MODULE__.new() |> Oban.insert()
  end

  @doc "Enqueue a reindex of a single media."
  def enqueue_media(id) when is_integer(id) do
    %{kind: "media", id: id} |> __MODULE__.new() |> Oban.insert()
  end

  @doc "Enqueue a 1-hop cascade reindex starting from an entity."
  def enqueue_entity_cascade(id) when is_integer(id) do
    %{kind: "entity_cascade", id: id} |> __MODULE__.new() |> Oban.insert()
  end

  @doc "Enqueue reindex for an explicit list of entity ids (and their attached media)."
  def enqueue_ids_cascade(ids) when is_list(ids) do
    ids = Enum.uniq(ids)
    %{kind: "ids_cascade", ids: ids} |> __MODULE__.new() |> Oban.insert()
  end

  # =====================================================================
  # Private helpers
  # =====================================================================

  defp neighbors_of(entity_id) do
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

  defp media_for_entities([]), do: []

  defp media_for_entities(entity_ids) do
    Repo.all(
      from em in EntityMedia,
        where: em.entity_id in ^entity_ids,
        distinct: true,
        select: em.media_id
    )
  end
end
