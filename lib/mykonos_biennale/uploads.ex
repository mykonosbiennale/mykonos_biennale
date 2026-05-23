defmodule MykonosBiennale.Uploads do
  @moduledoc """
  Centralized upload path configuration and media URL generation.

  In development, uploads are stored in priv/static/uploads.
  In production, they are stored on the persistent volume at /data/uploads.
  """

  alias MykonosBiennale.Thumbnail

  def uploads_dir do
    Application.get_env(:mykonos_biennale, :uploads_dir) ||
      Path.join(["priv", "static", "uploads"])
  end

  def uploads_path(filename) do
    Path.join([uploads_dir(), filename])
  end

  def uploads_url(filename) when is_binary(filename) do
    "/uploads/#{filename}"
  end

  def ensure_uploads_dir do
    File.mkdir_p!(uploads_dir())
  end

  @doc """
  Returns the WebP thumbnail URL for a media struct at the given size.

  Uses slug-based URLs when available, falls back to legacy UUID-based URLs.
  Suitable for use as an `<img>` src or CSS background-image.

  ## Supported sizes

    * `"hero"`  - 1920x1080
    * `"card"`  - 800x600
    * `"thumb"` - 400x300
    * `"admin"` - 300x300
  """
  def media_url(media, opts \\ [])

  def media_url(%{source_type: "upload", source_path: path, slug: slug}, opts)
      when is_binary(slug) and is_binary(path) do
    size = Keyword.get(opts, :size, "card")

    if image_path?(path) do
      Thumbnail.slug_thumbnail_url(slug, size)
    else
      "/uploads/#{path}"
    end
  end

  def media_url(%{source_type: "upload", source_path: path}, opts) when is_binary(path) do
    size = Keyword.get(opts, :size, "card")

    if image_path?(path) do
      {width, height} = size_to_dimensions(size)
      Thumbnail.thumbnail_url(path, width, height)
    else
      "/uploads/#{path}"
    end
  end

  def media_url(%{source_type: "url", source_url: url}, _opts) when is_binary(url), do: url
  def media_url(_, _opts), do: nil

  defp image_path?(path) do
    ext = Path.extname(path) |> String.downcase()
    ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"]
  end

  defp size_to_dimensions("hero"), do: {1920, 1080}
  defp size_to_dimensions("card"), do: {800, 600}
  defp size_to_dimensions("thumb"), do: {400, 300}
  defp size_to_dimensions("admin"), do: {300, 300}
  defp size_to_dimensions(_), do: {800, 600}
end