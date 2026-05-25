defmodule MykonosBiennale.Thumbnail do
  @moduledoc """
  Generates and caches image thumbnails using ImageMagick.

  Produces WebP, AVIF, and JPEG thumbnails named by slug for SEO-friendly URLs.
  Originals live in the uploads dir. Optimized versions are cached in the media dir.

  File naming: `{slug}-{size}.{ext}`
  Examples:
    `katherine-liberovskaya-2a-card.webp`
    `katherine-liberovskaya-2a-card.avif`
    `katherine-liberovskaya-2a-card.jpg`

  Backward compatible: the old `thumbnails/WxH/UUID.webp` format
  still works via the old URL pattern `/media/WxH/UUID.webp`.
  """

  alias MykonosBiennale.MediaDir
  alias MykonosBiennale.Uploads

  @doc """
  Returns the absolute filesystem path for a slug-based thumbnail.
  Creates the media directory if it doesn't exist.
  """
  @spec slug_thumbnail_path(String.t(), String.t(), String.t()) :: String.t()
  def slug_thumbnail_path(slug, size, ext \\ ".webp") do
    MediaDir.ensure_media_dir()
    MediaDir.path(slug, size, ext)
  end

  @doc """
  Returns the URL for a slug-based thumbnail.
  Example: `/media/katherine-liberovskaya-2a-card.webp`
  """
  @spec slug_thumbnail_url(String.t(), String.t(), String.t()) :: String.t()
  def slug_thumbnail_url(slug, size, ext \\ ".webp") do
    MediaDir.url(slug, size, ext)
  end

  @doc """
  Ensures a slug-based WebP thumbnail exists, generating it if necessary.
  Returns {:ok, path} or {:original, path} if generation fails.
  """
  @spec ensure_slug_thumbnail(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:original, String.t()}
  def ensure_slug_thumbnail(slug, source_path, size) do
    thumb_path = slug_thumbnail_path(slug, size, ".webp")
    original_path = Uploads.uploads_path(source_path)

    cond do
      File.exists?(thumb_path) ->
        {:ok, thumb_path}

      not File.exists?(original_path) ->
        {:original, original_path}

      not image_ext?(source_path) ->
        {:original, original_path}

      true ->
        {width, height} = MediaDir.size_dimensions(size)
        generate_thumbnail(original_path, thumb_path, width, height)
    end
  end

  @doc """
  Ensures a slug-based JPEG variant exists, generating it if necessary.
  Returns {:ok, path} or {:original, path} if generation fails.
  """
  @spec ensure_slug_jpeg(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:original, String.t()}
  def ensure_slug_jpeg(slug, source_path, size) do
    jpeg_path = slug_thumbnail_path(slug, size, ".jpg")
    original_path = Uploads.uploads_path(source_path)

    cond do
      File.exists?(jpeg_path) ->
        {:ok, jpeg_path}

      not File.exists?(original_path) ->
        {:original, original_path}

      not image_ext?(source_path) ->
        {:original, original_path}

      true ->
        {width, height} = MediaDir.size_dimensions(size)
        generate_jpeg(original_path, jpeg_path, width, height)
    end
  end

  @doc """
  Returns the absolute path to a legacy UUID-based thumbnail.
  Creates the thumbnails directory if needed.
  """
  @spec thumbnail_path(String.t(), pos_integer(), pos_integer()) :: String.t()
  def thumbnail_path(original_filename, width, height) do
    uploads_dir = Uploads.uploads_dir()
    thumbs_root = Path.join(Path.dirname(uploads_dir), "thumbnails")
    dir = Path.join(thumbs_root, "#{width}x#{height}")
    File.mkdir_p!(dir)
    basename = Path.basename(original_filename, Path.extname(original_filename))
    Path.join(dir, basename <> ".webp")
  end

  @doc """
  Returns the URL for a legacy UUID-based thumbnail.
  Example: `/media/800x600/UUID.webp`
  """
  @spec thumbnail_url(String.t(), pos_integer(), pos_integer()) :: String.t()
  def thumbnail_url(original_filename, width, height) do
    basename = Path.basename(original_filename, Path.extname(original_filename))
    "/media/#{width}x#{height}/#{basename}.webp"
  end

  @doc """
  Ensures a legacy UUID-based thumbnail exists, generating it if necessary.
  Falls back to the original if ImageMagick is unavailable or the file is not an image.
  """
  @spec ensure_thumbnail(String.t(), pos_integer(), pos_integer()) ::
          {:ok, String.t()} | {:original, String.t()}
  def ensure_thumbnail(original_filename, width, height) do
    original_path = Uploads.uploads_path(original_filename)
    thumb_path = thumbnail_path(original_filename, width, height)

    cond do
      File.exists?(thumb_path) ->
        {:ok, thumb_path}

      not File.exists?(original_path) ->
        {:original, original_path}

      not image_ext?(original_filename) ->
        {:original, original_path}

      true ->
        generate_thumbnail(original_path, thumb_path, width, height)
    end
  end

  @doc """
  Deletes all cached thumbnail variants (WebP, AVIF, JPEG) for a slug.
  Called when a media record is updated or deleted so stale cached files
  are regenerated on the next request.
  """
  @spec invalidate_slug_cache(String.t()) :: :ok
  def invalidate_slug_cache(slug) when is_binary(slug) do
    exts = [".webp", ".avif", ".jpg"]

    for size <- Map.keys(MediaDir.sizes()) ++ ["press"], ext <- exts do
      path = MediaDir.path(slug, size, ext)
      File.rm(path)
    end

    :ok
  end

  defp image_ext?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"]
  end

  defp generate_thumbnail(original_path, thumb_path, width, height) do
    args = [
      original_path,
      "-resize", "#{width}x#{height}^",
      "-gravity", "center",
      "-extent", "#{width}x#{height}",
      "-quality", "80",
      "-strip",
      thumb_path
    ]

    cmd = if System.find_executable("magick"), do: "magick", else: "convert"

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, thumb_path}

      {error, _code} ->
        require Logger
        Logger.warning("Thumbnail generation failed for #{original_path}: #{error}")
        {:original, original_path}
    end
  end

  defp generate_jpeg(original_path, jpeg_path, width, height) do
    args = [
      original_path,
      "-resize", "#{width}x#{height}^",
      "-gravity", "center",
      "-extent", "#{width}x#{height}",
      "-quality", "85",
      "-strip",
      jpeg_path
    ]

    cmd = if System.find_executable("magick"), do: "magick", else: "convert"

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, jpeg_path}

      {error, _code} ->
        require Logger
        Logger.warning("JPEG generation failed for #{original_path}: #{error}")
        {:original, original_path}
    end
  end
end