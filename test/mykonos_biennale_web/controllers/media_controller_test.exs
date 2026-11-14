defmodule MykonosBiennaleWeb.MediaControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Uploads

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

  describe "GET /media/:filename (slug route, other formats)" do
    setup do
      media =
        ContentFixtures.media_fixture(source_path: "fmt-test-#{System.unique_integer()}.jpg")

      test_jpg = Path.expand("test/support/fixtures/files/test.jpg")
      File.cp!(test_jpg, Path.join(Uploads.uploads_dir(), media.source_path))
      {:ok, media: media}
    end

    test "serves a jpg thumbnail", %{conn: conn, media: media} do
      conn = get(conn, "/media/#{media.slug}-card.jpg")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/jpeg"
    end

    test "serves a jpeg thumbnail", %{conn: conn, media: media} do
      conn = get(conn, "/media/#{media.slug}-thumb.jpeg")
      assert conn.status == 200
    end

    test "404 for an unknown slug in jpg form", %{conn: conn} do
      assert get(conn, "/media/unknown-slug-card.jpg").status == 404
    end

    test "404 for an unknown slug in jpeg form", %{conn: conn} do
      assert get(conn, "/media/unknown-slug-card.jpeg").status == 404
    end

    test "404 for an unknown slug in avif form", %{conn: conn} do
      assert get(conn, "/media/unknown-slug-card.avif").status == 404
    end

    test "404 when the source file is missing", %{conn: conn} do
      # A unique caption gives a unique slug, so no cached thumbnail from
      # another test can be served for this media.
      media =
        ContentFixtures.media_fixture(
          caption: "Missing source #{System.unique_integer()}",
          source_path: "missing-#{System.unique_integer()}.jpg"
        )

      assert get(conn, "/media/#{media.slug}-card.jpg").status == 404
    end
  end

  describe "fallbacks and other sizes" do
    test "a file that is not an image is served as the original", %{conn: conn} do
      name = "bogus-#{System.unique_integer([:positive])}.jpg"
      File.mkdir_p!(Uploads.uploads_dir())
      File.write!(Path.join(Uploads.uploads_dir(), name), "this is not a jpeg")

      conn = get(conn, "/media/card/#{name}")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/jpeg"
    end

    test "a custom WIDTHxHEIGHT size is accepted", %{conn: conn, filename: filename} do
      conn = get(conn, "/media/640x480/#{filename}")
      assert conn.status == 200
    end

    test "an unreadable original on the legacy route is a 404", %{conn: conn} do
      name = "missing-#{System.unique_integer([:positive])}.jpg"
      conn = get(conn, "/media/card/#{name}")
      assert conn.status == 404
    end

    test "an avif request for a slug is answered with an image", %{conn: conn} do
      media =
        ContentFixtures.media_fixture(
          caption: "AVIF #{System.unique_integer([:positive])}",
          source_path: "avif-test-#{System.unique_integer()}.jpg"
        )

      File.cp!(
        Path.expand("test/support/fixtures/files/test.jpg"),
        Path.join(Uploads.uploads_dir(), media.source_path)
      )

      conn = get(conn, "/media/#{media.slug}-card.avif")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/"
    end
  end

  describe "slug routes when the source is not an image" do
    setup do
      File.mkdir_p!(Uploads.uploads_dir())

      make = fn ext ->
        name = "broken-#{System.unique_integer([:positive])}#{ext}"
        File.write!(Path.join(Uploads.uploads_dir(), name), "not an image")

        ContentFixtures.media_fixture(
          caption: "Broken #{ext} #{System.unique_integer([:positive])}",
          source_path: name
        )
      end

      {:ok, make: make}
    end

    test "a jpg request serves the original with its own mime type", %{conn: conn, make: make} do
      media = make.(".png")
      conn = get(conn, "/media/#{media.slug}-card.jpg")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/png"
    end

    test "a webp request serves the original when the thumbnail cannot be made", %{
      conn: conn,
      make: make
    } do
      media = make.(".gif")
      conn = get(conn, "/media/#{media.slug}-card.webp")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/gif"
    end

    test "an avif request falls back when the avif cannot be made", %{conn: conn, make: make} do
      media = make.(".bmp")
      conn = get(conn, "/media/#{media.slug}-card.avif")
      assert conn.status == 200
    end

    test "an unknown extension is served as an octet stream", %{conn: conn, make: make} do
      media = make.(".xyz")
      conn = get(conn, "/media/#{media.slug}-card.jpg")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "application/octet-stream"
    end
  end
end
