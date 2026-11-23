defmodule MykonosBiennaleWeb.Admin.MediaVisibilityTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Media
  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Uploads

  defp url_media(url) do
    {:ok, media} = Content.create_media(%{source_type: "url", source_url: url})
    media
  end

  test "Retire hides a media record and Restore shows it again", %{conn: conn} do
    media = url_media("https://example.com/#{System.unique_integer()}.jpg")
    {:ok, lv, _html} = live(conn, ~p"/admin/media")

    html = render_hook(lv, "toggle_visible", %{"id" => to_string(media.id)})
    refute Repo.get!(Media, media.id).visible
    assert html =~ "Retired"

    render_hook(lv, "toggle_visible", %{"id" => to_string(media.id)})
    assert Repo.get!(Media, media.id).visible
  end

  test "a retired record is not offered by the pickers" do
    media = url_media("https://example.com/#{System.unique_integer()}.jpg")
    assert media.id in Enum.map(Content.list_media(), & &1.id)

    {:ok, _} = Content.set_media_visible(media, false)

    refute media.id in Enum.map(Content.list_media(), & &1.id)
  end

  test "a retired record is hidden from its entity" do
    event = ContentFixtures.event_fixture(%{title: "Hidden media"})
    media = ContentFixtures.media_fixture(caption: "Hidden picture")
    {:ok, _} = Content.attach_media_to_entity(event, media)
    assert Enum.map(Content.list_media_for_entity(event), & &1.id) == [media.id]

    {:ok, _} = Content.set_media_visible(media, false)

    assert Content.list_media_for_entity(event) == []
  end

  test "restoring is refused while another visible record has the same file" do
    Uploads.ensure_uploads_dir()
    bytes = "same-#{System.unique_integer()}"

    first = copy_upload(bytes)
    {:ok, original} = Content.create_media(upload_attrs(first))
    {:ok, _} = Content.set_media_visible(original, false)

    second = copy_upload(bytes)
    {:ok, replacement} = Content.create_media(upload_attrs(second))
    assert replacement.visible

    assert {:error, :duplicate} = Content.set_media_visible(Repo.get!(Media, original.id), true)
    refute Repo.get!(Media, original.id).visible
  end

  defp upload_attrs(name) do
    %{source_type: "upload", source_path: name, original_name: name, caption: "Copy"}
  end

  defp copy_upload(bytes) do
    name = "#{Ecto.UUID.generate()}.jpg"
    File.write!(Uploads.uploads_path(name), bytes)
    on_exit(fn -> File.rm(Uploads.uploads_path(name)) end)
    name
  end
end
