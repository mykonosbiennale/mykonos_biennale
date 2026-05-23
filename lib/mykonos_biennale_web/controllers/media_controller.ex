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
            serve_slug_thumbnail(conn, media, size)
        end

      {:ok, %{slug: slug, size: _size, ext: ext}} when ext in [".jpg", ".jpeg", ".png"] ->
        case Content.get_media_by_slug(slug) do
          nil ->
            conn
            |> put_status(404)
            |> text("Not found")

          media ->
            serve_original_variant(conn, media, ext)
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

  defp serve_slug_thumbnail(conn, media, size) do
    case Thumbnail.ensure_slug_thumbnail(media.slug, media.source_path, size) do
      {:ok, thumb_path} ->
        conn
        |> put_resp_header("content-type", "image/webp")
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

  defp serve_original_variant(conn, media, ext) do
    original_path = MykonosBiennale.Uploads.uploads_path(media.source_path)

    if File.exists?(original_path) do
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

  defp parse_dimensions(dim) do
    case Map.get(@sizes, dim) do
      {w, h} -> {w, h}
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