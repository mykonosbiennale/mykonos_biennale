defmodule MykonosBiennaleWeb.MediaController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Content
  alias MykonosBiennale.Thumbnail

  @sizes %{
    "hero" => {1920, 1080},
    "card" => {800, 600},
    "thumb" => {400, 300},
    "admin" => {300, 300}
  }

  @source_exts ~w(.jpg .jpeg .png .gif .webp .bmp .tiff .tif)

  @doc """
  Handles slug-based URLs: /media/:filename
  e.g. /media/katherine-liberovskaya-2a-card.webp
  e.g. /media/katherine-liberovskaya-2a-card.avif
  """
  def show_slug(conn, %{"filename" => filename}) do
    case MykonosBiennale.MediaDir.parse_filename(filename) do
      {:ok, %{slug: slug, size: size, ext: ".webp"}} ->
        case Content.get_media_by_slug(slug) do
          nil ->
            conn
            |> put_status(404)
            |> text("Not found")

          media ->
            serve_slug_thumbnail(conn, media, size, "image/webp")
        end

      {:ok, %{slug: slug, size: size, ext: ".avif"}} ->
        case Content.get_media_by_slug(slug) do
          nil ->
            conn
            |> put_status(404)
            |> text("Not found")

          media ->
            serve_avif(conn, media, size)
        end

      {:ok, %{slug: slug, size: size, ext: ".jpg"}} ->
        case Content.get_media_by_slug(slug) do
          nil ->
            conn
            |> put_status(404)
            |> text("Not found")

          media ->
            serve_slug_jpeg(conn, media, size)
        end

      {:ok, %{slug: slug, size: size, ext: ".jpeg"}} ->
        case Content.get_media_by_slug(slug) do
          nil ->
            conn
            |> put_status(404)
            |> text("Not found")

          media ->
            serve_slug_jpeg(conn, media, size)
        end

      _ ->
        conn
        |> put_status(404)
        |> text("Not found")
    end
  end

  @doc """
  Handles legacy UUID-based URLs: /media/:dimensions/:filename
  e.g. /media/800x600/UUID.webp
  """
  def show(conn, %{"dimensions" => dimensions, "filename" => filename}) do
    {width, height} = parse_dimensions(dimensions)
    basename = Path.rootname(filename)

    original_filename =
      @source_exts
      |> Enum.find("#{basename}.jpg", fn ext ->
        File.exists?(MykonosBiennale.Uploads.uploads_path("#{basename}#{ext}"))
      end)
      |> then(&"#{basename}#{&1}")

    case Thumbnail.ensure_thumbnail(original_filename, width, height) do
      {:ok, thumb_path} ->
        ext = Path.extname(thumb_path)
        mime = mime_type(ext)

        conn
        |> put_resp_header("content-type", mime)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, thumb_path)

      {:original, original_path} ->
        if File.exists?(original_path) do
          ext = Path.extname(original_filename) |> String.downcase()
          mime = mime_type(ext)

          conn
          |> put_resp_header("content-type", mime)
          |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
          |> send_file(200, original_path)
        else
          conn
          |> put_status(404)
          |> text("Not found")
        end
    end
  end

  defp serve_slug_thumbnail(conn, media, size, content_type) do
    case Thumbnail.ensure_slug_thumbnail(media.slug, media.source_path, size) do
      {:ok, thumb_path} ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, thumb_path)

      {:original, original_path} ->
        if File.exists?(original_path) do
          ext = Path.extname(media.source_path) |> String.downcase()
          mime = mime_type(ext)

          conn
          |> put_resp_header("content-type", mime)
          |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
          |> send_file(200, original_path)
        else
          conn
          |> put_status(404)
          |> text("Not found")
        end
    end
  end

  defp serve_avif(conn, media, size) do
    avif_path = MykonosBiennale.MediaDir.path(media.slug, size, ".avif")

    if File.exists?(avif_path) do
      conn
      |> put_resp_header("content-type", "image/avif")
      |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
      |> send_file(200, avif_path)
    else
      case Thumbnail.ensure_slug_thumbnail(media.slug, media.source_path, size) do
        {:ok, webp_path} ->
          case generate_avif_from_webp(webp_path, avif_path) do
            :ok ->
              conn
              |> put_resp_header("content-type", "image/avif")
              |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
              |> send_file(200, avif_path)

            :error ->
              serve_slug_thumbnail(conn, media, size, "image/webp")
          end

        {:original, original_path} ->
          if File.exists?(original_path) do
            ext = Path.extname(media.source_path) |> String.downcase()
            mime = mime_type(ext)

            conn
            |> put_resp_header("content-type", mime)
            |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
            |> send_file(200, original_path)
          else
            conn
            |> put_status(404)
            |> text("Not found")
          end
      end
    end
  end

  defp generate_avif_from_webp(webp_path, avif_path) do
    media_dir = Path.expand(MykonosBiennale.MediaDir.media_dir())

    if not String.starts_with?(Path.expand(avif_path), media_dir) do
      require Logger
      Logger.warning("AVIF path outside media dir rejected: #{avif_path}")
      :error
    else
      cmd = System.find_executable("magick") || "convert"

      args = [webp_path, "-quality", "65", "-strip", avif_path]

      case System.cmd(cmd, args, stderr_to_stdout: true) do
        {_, 0} ->
          :ok

        {error, _code} ->
          require Logger
          Logger.warning("AVIF generation failed for #{webp_path}: #{error}")
          File.rm(avif_path)
          :error
      end
    end
  end

  defp serve_slug_jpeg(conn, media, size) do
    case Thumbnail.ensure_slug_jpeg(media.slug, media.source_path, size) do
      {:ok, jpeg_path} ->
        conn
        |> put_resp_header("content-type", "image/jpeg")
        |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
        |> send_file(200, jpeg_path)

      {:original, original_path} ->
        if File.exists?(original_path) do
          ext = Path.extname(media.source_path) |> String.downcase()
          mime = mime_type(ext)

          conn
          |> put_resp_header("content-type", mime)
          |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
          |> send_file(200, original_path)
        else
          conn
          |> put_status(404)
          |> text("Not found")
        end
    end
  end

  defp parse_dimensions(dim) do
    case Map.get(@sizes, dim) do
      {w, h} ->
        {w, h}

      nil ->
        case String.split(dim, "x") do
          [w, h] -> {String.to_integer(w), String.to_integer(h)}
          _ -> {1200, 800}
        end
    end
  end

  defp mime_type(".avif"), do: "image/avif"
  defp mime_type(".jpg"), do: "image/jpeg"
  defp mime_type(".jpeg"), do: "image/jpeg"
  defp mime_type(".png"), do: "image/png"
  defp mime_type(".gif"), do: "image/gif"
  defp mime_type(".webp"), do: "image/webp"
  defp mime_type(".bmp"), do: "image/bmp"
  defp mime_type(_), do: "application/octet-stream"
end
