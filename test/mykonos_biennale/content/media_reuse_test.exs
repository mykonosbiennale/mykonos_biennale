defmodule MykonosBiennale.Content.MediaReuseTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Uploads

  defp upload_attrs(name, caption \\ "Caption") do
    %{
      source_type: "upload",
      source_path: name,
      original_name: name,
      mime_type: "image/jpeg",
      caption: caption
    }
  end

  # Stores bytes under a fresh name, as the upload screens do before calling create_media.
  defp copy_upload(bytes) do
    Uploads.ensure_uploads_dir()
    name = "#{Ecto.UUID.generate()}.jpg"
    File.write!(Uploads.uploads_path(name), bytes)
    on_exit(fn -> File.rm(Uploads.uploads_path(name)) end)
    name
  end

  test "the same file bytes reuse the existing record and remove the new copy" do
    bytes = "image-#{System.unique_integer()}"
    first = copy_upload(bytes)
    second = copy_upload(bytes)

    {:ok, original} = Content.create_media(upload_attrs(first, "First"))
    {:ok, reused} = Content.create_media(upload_attrs(second, "Second"))

    assert reused.id == original.id
    assert reused.reused
    refute original.reused
    assert reused.caption == "First"
    refute File.exists?(Uploads.uploads_path(second))
    assert File.exists?(Uploads.uploads_path(first))
  end

  test "a retired record is never reused" do
    bytes = "image-#{System.unique_integer()}"
    {:ok, retired} = Content.create_media(upload_attrs(copy_upload(bytes)))
    Repo.update!(Ecto.Changeset.change(retired, visible: false))

    {:ok, fresh} = Content.create_media(upload_attrs(copy_upload(bytes)))

    refute fresh.id == retired.id
    refute fresh.reused
    assert fresh.visible
  end

  test "different file bytes create separate records" do
    {:ok, a} = Content.create_media(upload_attrs(copy_upload("a-#{System.unique_integer()}")))
    {:ok, b} = Content.create_media(upload_attrs(copy_upload("b-#{System.unique_integer()}")))

    refute a.id == b.id
    refute a.fingerprint == b.fingerprint
  end

  test "on_duplicate: :error refuses the duplicate and creates nothing" do
    bytes = "image-#{System.unique_integer()}"
    {:ok, existing} = Content.create_media(upload_attrs(copy_upload(bytes)))
    copy = copy_upload(bytes)
    count = Repo.aggregate(Media, :count)

    assert {:error, {:duplicate, found}} =
             Content.create_media(upload_attrs(copy), on_duplicate: :error)

    assert found.id == existing.id
    assert Repo.aggregate(Media, :count) == count
    refute File.exists?(Uploads.uploads_path(copy))
  end

  test "the same URL reuses the existing record, and a different URL does not" do
    url = "https://example.com/#{System.unique_integer()}.jpg"
    {:ok, first} = Content.create_media(%{source_type: "url", source_url: url})
    {:ok, second} = Content.create_media(%{source_type: "url", source_url: url})
    {:ok, other} = Content.create_media(%{source_type: "url", source_url: url <> "?x=1"})

    assert second.id == first.id
    assert other.id != first.id
  end

  test "the same embed code reuses the existing record" do
    embed = "<iframe src=\"https://www.youtube.com/embed/#{System.unique_integer()}\"></iframe>"
    {:ok, first} = Content.create_media(%{source_type: "embed", source_embed: embed})
    {:ok, second} = Content.create_media(%{source_type: "embed", source_embed: embed})

    assert second.id == first.id
  end

  test "a file missing from disk has no fingerprint and is never reused" do
    {:ok, first} = Content.create_media(upload_attrs("missing-#{System.unique_integer()}.jpg"))
    {:ok, second} = Content.create_media(upload_attrs("missing-#{System.unique_integer()}.jpg"))

    assert first.fingerprint == nil
    refute first.id == second.id
  end
end
