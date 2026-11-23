defmodule MykonosBiennale.Content.MediaDedupeIndexTest do
  # Runs the merge with the unique fingerprint index in place, as in a real database.
  # Unlike MediaDedupeTest, nothing here drops the index.
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Content.MediaDedupe
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Uploads

  test "duplicates are retired and the merge completes with the unique index in place" do
    url = "https://example.com/#{System.unique_integer()}.jpg"
    keep = Repo.insert!(%Media{source_type: "url", source_url: url, caption: "Kept"})
    dup = Repo.insert!(%Media{source_type: "url", source_url: url})

    bytes = "same-#{System.unique_integer()}"
    first = upload_file(bytes)
    second = upload_file(bytes)

    report = MediaDedupe.run()

    assert report.duplicate_groups == 2
    assert report.retired == 2

    assert Repo.get!(Media, keep.id).visible
    assert Repo.get!(Media, keep.id).fingerprint
    refute Repo.get!(Media, dup.id).visible
    assert Repo.get!(Media, dup.id).fingerprint

    assert Repo.get!(Media, first.id).visible != Repo.get!(Media, second.id).visible
  end

  test "a second run after the merge changes nothing" do
    url = "https://example.com/#{System.unique_integer()}.jpg"
    Repo.insert!(%Media{source_type: "url", source_url: url})
    Repo.insert!(%Media{source_type: "url", source_url: url})
    MediaDedupe.run()

    report = MediaDedupe.run()

    assert report.duplicate_groups == 0
    assert report.retired == 0
  end

  defp upload_file(bytes) do
    Uploads.ensure_uploads_dir()
    name = "#{Ecto.UUID.generate()}.jpg"
    File.write!(Uploads.uploads_path(name), bytes)
    on_exit(fn -> File.rm(Uploads.uploads_path(name)) end)

    Repo.insert!(%Media{source_type: "upload", source_path: name, caption: name})
  end
end
