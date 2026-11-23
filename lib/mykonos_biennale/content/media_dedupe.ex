defmodule MykonosBiennale.Content.MediaDedupe do
  @moduledoc """
  Gives every media record a fingerprint and retires the duplicates.

  For each group of visible records that share a fingerprint, one record is kept:

    * the one with the best caption (a non-blank caption, then the longest one)
    * failing that, the oldest (lowest id)

  Every other record is tombstoned, not deleted: it is set to `visible: false` and its
  `metadata["merged_into"]` names the kept record. Its row and file stay, so old links
  and URLs still resolve. Before tombstoning, the merge moves the rest of the data over:

    * entity links (`entity_media`) move to the kept record; a link to an entity that
      already has the kept record is dropped
    * event art boards (`artboard_media_ids`) and relationship images (`image_media_id`)
      are repointed

  Each group is merged in its own transaction. Retired records are never grouped again,
  so running the merge twice changes nothing the second time. `run(dry_run: true)`
  counts what would change without writing.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.EntityMedia
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Content.MediaFingerprint
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Workers.SearchReindex

  @empty %{links_moved: 0, artboards: 0, relationships: 0, retired: 0}

  @doc "Runs the backfill and the merge. Returns a report map."
  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run, false)
    media = Repo.all(from m in Media, order_by: m.id)

    fingerprints =
      Map.new(media, fn m -> {m.id, m.fingerprint || MediaFingerprint.for_media(m)} end)

    fingerprinted = Enum.count(media, &(is_nil(&1.fingerprint) and fingerprints[&1.id]))
    groups = visible_duplicate_groups(media, fingerprints)

    # Records with a unique fingerprint can be stored straight away. Duplicates are
    # handled group by group, so the unique index never sees two visible copies.
    grouped_ids = groups |> List.flatten() |> MapSet.new(& &1.id)
    ungrouped = Enum.reject(media, &MapSet.member?(grouped_ids, &1.id))
    backfill(ungrouped, fingerprints, dry_run?)

    totals = Enum.reduce(groups, @empty, &merge_group(&1, &2, fingerprints, dry_run?))

    %{
      dry_run: dry_run?,
      media: length(media),
      missing_files:
        Enum.count(media, &(&1.source_type == "upload" and is_nil(fingerprints[&1.id]))),
      fingerprinted: fingerprinted,
      duplicate_groups: length(groups),
      retired: totals.retired,
      links_moved: totals.links_moved,
      artboards_updated: totals.artboards,
      relationships_updated: totals.relationships
    }
  end

  @doc """
  Chooses the record to keep from a group: a non-blank caption first, then the longest
  caption, then the oldest record.
  """
  def choose_keeper(records) do
    Enum.min_by(records, fn m ->
      caption = String.trim(m.caption || "")
      {if(caption == "", do: 1, else: 0), -String.length(caption), m.id}
    end)
  end

  # Stores fingerprints for records that do not have one yet.
  defp backfill(media, fingerprints, dry_run?) do
    unless dry_run? do
      media
      |> Enum.filter(&(is_nil(&1.fingerprint) and fingerprints[&1.id]))
      |> Enum.each(&store_fingerprint(&1.id, fingerprints[&1.id]))
    end
  end

  defp store_fingerprint(id, fingerprint) do
    Repo.update_all(from(x in Media, where: x.id == ^id), set: [fingerprint: fingerprint])
  end

  defp visible_duplicate_groups(media, fingerprints) do
    media
    |> Enum.filter(&(&1.visible and fingerprints[&1.id]))
    |> Enum.group_by(&fingerprints[&1.id])
    |> Enum.filter(fn {_fingerprint, records} -> length(records) > 1 end)
    |> Enum.map(fn {_fingerprint, records} -> records end)
  end

  # Duplicates are retired before the keeper gets its fingerprint: while two visible
  # records share a fingerprint, the unique index refuses the second write.
  defp merge_group(records, acc, fingerprints, dry_run?) do
    records = Enum.map(records, &%{&1 | fingerprint: fingerprints[&1.id]})
    keep = choose_keeper(records)

    totals =
      records
      |> Enum.reject(&(&1.id == keep.id))
      |> Enum.reduce(acc, fn dup, acc ->
        dup
        |> then(&merge_into(keep, &1, dry_run?))
        |> then(&Map.merge(acc, &1, fn _key, a, b -> a + b end))
      end)

    unless dry_run?, do: store_fingerprint(keep.id, keep.fingerprint)

    totals
  end

  defp merge_into(keep, dup, true = _dry_run), do: merge_steps(keep, dup, false)

  defp merge_into(keep, dup, false) do
    {:ok, counts} = Repo.transaction(fn -> merge_steps(keep, dup, true) end)
    counts
  end

  # `write?` is false for dry runs: each step still counts what it would change.
  defp merge_steps(keep, dup, write?) do
    %{
      links_moved: move_entity_links(keep, dup, write?),
      artboards: repoint_artboards(keep, dup, write?),
      relationships: repoint_relationship_images(keep, dup, write?),
      retired: if(write?, do: retire(keep, dup), else: 1)
    }
  end

  defp move_entity_links(keep, dup, write?) do
    kept_entities = from(em in EntityMedia, where: em.media_id == ^keep.id, select: em.entity_id)

    moving =
      from(em in EntityMedia,
        where: em.media_id == ^dup.id and em.entity_id not in subquery(kept_entities)
      )

    count = Repo.aggregate(moving, :count)

    if write? do
      Repo.update_all(moving, set: [media_id: keep.id])

      # Entities that already link the kept record: the duplicate's link is redundant.
      Repo.delete_all(from(em in EntityMedia, where: em.media_id == ^dup.id))
    end

    count
  end

  defp repoint_artboards(keep, dup, write?) do
    events =
      from(e in Entity, where: e.type == "event")
      |> Repo.all()
      |> Enum.filter(fn e -> dup.id in artboard_ids(e.fields) end)

    if write?, do: Enum.each(events, &replace_artboard_media(&1, keep.id, dup.id))

    length(events)
  end

  defp replace_artboard_media(entity, keep_id, dup_id) do
    ids =
      entity.fields
      |> artboard_ids()
      |> Enum.map(&if(&1 == dup_id, do: keep_id, else: &1))
      |> Enum.uniq()

    entity
    |> Changeset.change(fields: Map.put(entity.fields, "artboard_media_ids", ids))
    |> Repo.update!()

    SearchReindex.enqueue_entity(entity.id)
  end

  defp artboard_ids(fields), do: int_ids((fields || %{})["artboard_media_ids"])

  defp repoint_relationship_images(keep, dup, write?) do
    relationships =
      from(r in Relationship, where: not is_nil(r.fields))
      |> Repo.all()
      |> Enum.filter(fn r -> int_id((r.fields || %{})["image_media_id"]) == dup.id end)

    if write?, do: Enum.each(relationships, &write_relationship_image(&1, keep.id))

    length(relationships)
  end

  # Keeps the stored type: a string id stays a string.
  defp write_relationship_image(relationship, keep_id) do
    value =
      if is_binary(relationship.fields["image_media_id"]), do: to_string(keep_id), else: keep_id

    relationship
    |> Changeset.change(fields: Map.put(relationship.fields, "image_media_id", value))
    |> Repo.update!()
  end

  # Hides the duplicate and records which record replaced it. Its fingerprint and file
  # are kept, so the record still shows where it came from.
  defp retire(keep, dup) do
    metadata = Map.put(dup.metadata || %{}, "merged_into", keep.id)

    # update_all writes every field given. A changeset would skip the fingerprint, because
    # the in-memory struct already holds that value.
    Repo.update_all(from(x in Media, where: x.id == ^dup.id),
      set: [visible: false, metadata: metadata, fingerprint: dup.fingerprint]
    )

    SearchReindex.enqueue_media(dup.id)
    1
  end

  defp int_ids(nil), do: []
  defp int_ids(ids) when is_list(ids), do: Enum.map(ids, &int_id/1)
  defp int_ids(_other), do: []

  defp int_id(value) when is_integer(value), do: value

  defp int_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp int_id(_value), do: nil
end
