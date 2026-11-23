defmodule MykonosBiennale.Content.MediaDedupeTest do
  # Dropping the unique index needs exclusive access to the table, so this module runs
  # alone. The drop is inside the test transaction, so it is rolled back afterwards.
  use MykonosBiennale.DataCase, async: false

  import Ecto.Query

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.EntityMedia
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Content.MediaDedupe
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Uploads

  setup do
    Repo.query!("DROP INDEX IF EXISTS media_fingerprint_index")
    :ok
  end

  test "merges URL duplicates into the oldest record and moves its links" do
    url = "https://example.com/#{System.unique_integer()}.jpg"
    keep = Repo.insert!(%Media{source_type: "url", source_url: url})
    dup = Repo.insert!(%Media{source_type: "url", source_url: url})

    event_a = ContentFixtures.event_fixture(%{title: "Event A"})
    event_b = ContentFixtures.event_fixture(%{title: "Event B"})

    Repo.insert!(%EntityMedia{entity_id: event_a.id, media_id: dup.id, position: 0})
    Repo.insert!(%EntityMedia{entity_id: event_b.id, media_id: dup.id, position: 0})
    Repo.insert!(%EntityMedia{entity_id: event_b.id, media_id: keep.id, position: 1})

    report = MediaDedupe.run(dry_run: true)
    assert report.duplicate_groups == 1
    assert report.retired == 1
    assert Repo.get!(Media, dup.id).visible

    report = MediaDedupe.run()
    assert report.retired == 1
    assert report.links_moved == 1
    refute Repo.get!(Media, dup.id).visible
    assert Repo.get!(Media, keep.id).visible

    assert linked_media_ids(event_a) == [keep.id]
    assert linked_media_ids(event_b) == [keep.id]
  end

  test "repoints art boards and relationship images to the kept record" do
    keep = upload_media("first", "first.jpg")
    dup = upload_media("first", "copy.jpg")
    other = upload_media("other", "other.jpg")

    event = ContentFixtures.event_fixture(%{title: "Art show"})
    member = ContentFixtures.event_fixture(%{title: "Member"})

    {:ok, event} =
      event
      |> Ecto.Changeset.change(
        fields: Map.put(event.fields, "artboard_media_ids", [dup.id, other.id])
      )
      |> Repo.update()

    ContentFixtures.create_relationship(member, event, "biennale_event", %{
      "image_media_id" => dup.id
    })

    report = MediaDedupe.run()

    assert report.retired == 1
    assert report.artboards_updated == 1
    assert report.relationships_updated == 1
    refute Repo.get!(Media, dup.id).visible
    assert Repo.get(Entity, event.id).fields["artboard_media_ids"] == [keep.id, other.id]

    relationship =
      Relationship |> Repo.all() |> Enum.find(&(&1.fields["image_media_id"] != nil))

    assert relationship.fields["image_media_id"] == keep.id
  end

  test "retired duplicates keep their row, file and a pointer to the kept record" do
    keep = upload_media("same bytes", "keep.jpg")
    dup = upload_media("same bytes", "dup.jpg")

    MediaDedupe.run()

    retired = Repo.get!(Media, dup.id)
    refute retired.visible
    assert retired.metadata["merged_into"] == keep.id
    assert retired.fingerprint
    assert File.exists?(Uploads.uploads_path(dup.source_path))
    assert File.exists?(Uploads.uploads_path(keep.source_path))
  end

  test "the record with the best caption is kept, then the oldest" do
    blank = upload_media("bytes", "blank.jpg")
    short = upload_media("bytes", "short")
    long = upload_media("bytes", "a much longer caption")
    Repo.update!(Ecto.Changeset.change(blank, caption: nil))

    MediaDedupe.run()

    assert Repo.get!(Media, long.id).visible
    refute Repo.get!(Media, short.id).visible
    refute Repo.get!(Media, blank.id).visible
    assert Repo.get!(Media, short.id).metadata["merged_into"] == long.id
  end

  test "the oldest record is kept when no captions differ" do
    first = upload_media("same", nil)
    second = upload_media("same", nil)

    MediaDedupe.run()

    assert Repo.get!(Media, first.id).visible
    refute Repo.get!(Media, second.id).visible
  end

  test "running the merge again changes nothing" do
    upload_media("same", "one")
    upload_media("same", "two")
    MediaDedupe.run()

    report = MediaDedupe.run()

    assert report.duplicate_groups == 0
    assert report.retired == 0
  end

  # Writes a file with the given bytes into the uploads folder and stores it as media
  # with a fingerprint. The index is dropped in these tests, so duplicates can exist.
  defp upload_media(bytes, original_name) do
    Uploads.ensure_uploads_dir()
    name = "#{Ecto.UUID.generate()}.jpg"
    File.write!(Uploads.uploads_path(name), bytes)
    on_exit(fn -> File.rm(Uploads.uploads_path(name)) end)

    Repo.insert!(%Media{
      source_type: "upload",
      source_path: name,
      original_name: original_name,
      caption: original_name
    })
  end

  defp linked_media_ids(entity) do
    Repo.all(from em in EntityMedia, where: em.entity_id == ^entity.id, select: em.media_id)
  end
end
