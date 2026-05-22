defmodule MykonosBiennale.Thumbnail do
  @moduledoc """
  Generates and caches image thumbnails using ImageMagick.

  Originals live in the uploads dir. Thumbnails are cached in a sibling
  `thumbnails` directory so /data/uploads/UUID.jpg → /data/thumbnails/WxH/UUID.webp
  """

  @spec thumbnail_path(String.t(), pos_integer(), pos_integer()) :: String.t()
  def thumbnail_path(original_filename, width, height) do
    uploads_dir = MykonosBiennale.Uploads.uploads_dir()
    thumbs_root = Path.join(Path.dirname(uploads_dir), "thumbnails")
    dir = Path.join(thumbs_root, "#{width}x#{height}")
    File.mkdir_p!(dir)
    ext = ".webp"
    Path.join(dir, Path.basename(original_filename, Path.extname(original_filename)) <> ext)
  end

  @spec thumbnail_url(String.t(), pos_integer(), pos_integer()) :: String.t()
  def thumbnail_url(original_filename, width, height) do
    "/media/#{width}x#{height}/#{Path.basename(original_filename, Path.extname(original_filename))}.webp"
  end

  @doc """
  Returns the absolute path to a thumbnail, creating it if necessary.
  Falls back to the original if ImageMagick is unavailable or the file is not an image.
  """
  @spec ensure_thumbnail(String.t(), pos_integer(), pos_integer()) :: {:ok, String.t()} | {:original, String.t()}
  def ensure_thumbnail(original_filename, width, height) do
    uploads_dir = MykonosBiennale.Uploads.uploads_dir()
    original_path = Path.join(uploads_dir, original_filename)
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

  defp image_ext?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"]
  end

  defp generate_thumbnail(original_path, thumb_path, width, height) do
    args = [
      original_path,
      "-resize",
      "#{width}x#{height}^",
      "-gravity",
      "center",
      "-extent",
      "#{width}x#{height}",
      "-quality",
      "80",
      "-strip",
      thumb_path
    ]

    case System.cmd("convert", args, stderr_to_stdout: true) do
      {_, 0} ->
        {:ok, thumb_path}

      {error, _code} ->
        require Logger
        Logger.warning("Thumbnail generation failed for #{original_path}: #{error}")
        {:original, original_path}
    end
  end
end