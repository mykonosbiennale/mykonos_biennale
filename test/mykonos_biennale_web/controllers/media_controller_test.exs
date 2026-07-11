defmodule MykonosBiennaleWeb.MediaControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.Uploads
  alias MykonosBiennale.ContentFixtures

  setup do
    File.mkdir_p!(Uploads.uploads_dir())
    test_jpg = Path.expand("test/support/fixtures/files/test.jpg")
    filename = "media-test-#{System.unique_integer()}.jpg"
    dest = Path.join(Uploads.uploads_dir(), filename)
    File.cp!(test_jpg, dest)
    {:ok, filename: filename}
  end

  describe "GET /media/:dimensions/:filename (legacy UUID route)" do
    test "serves thumbnail for existing file", %{conn: conn, filename: filename} do
      conn = get(conn, "/media/card/#{filename}")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image"
    end

    test "404 for non-existent file", %{conn: conn} do
      conn = get(conn, "/media/card/nonexistent-file.jpg")
      assert conn.status == 404
    end
  end

  describe "GET /media/:filename (slug route)" do
    test "serves webp thumbnail for media with slug", %{conn: conn} do
      media =
        ContentFixtures.media_fixture(source_path: "test-media-#{System.unique_integer()}.jpg")

      test_jpg = Path.expand("test/support/fixtures/files/test.jpg")
      File.cp!(test_jpg, Path.join(Uploads.uploads_dir(), media.source_path))

      filename = "#{media.slug}-card.webp"
      conn = get(conn, "/media/#{filename}")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image"
    end

    test "404 for unknown media slug", %{conn: conn} do
      conn = get(conn, "/media/unknown-slug-card.webp")
      assert conn.status == 404
    end

    test "404 for unparseable filename", %{conn: conn} do
      conn = get(conn, "/media/no-size-here.txt")
      assert conn.status == 404
    end
  end
end
