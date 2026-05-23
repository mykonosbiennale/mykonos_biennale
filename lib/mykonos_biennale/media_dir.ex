defmodule MykonosBiennale.MediaDir do
  @moduledoc """
  Manages the media output directory for SEO-friendly, optimized files.

  Originals live in Uploads.uploads_dir() and are never modified.
  Optimized versions (WebP, AVIF, press JPEG) live in media_dir().

  File naming: `{slug}-{size}.{ext}`
  Example: `katherine-liberovskaya-2a-card.webp`
  """

  @sizes %{
    "hero" => {1920, 1080},
    "card" => {800, 600},
    "thumb" => {400, 300},
    "admin" => {300, 300}
  }

  def media_dir do
    Application.get_env(:mykonos_biennale, :media_dir) ||
      Path.join([:code.priv_dir(:mykonos_biennale), "static", "media"])
  end

  def media_path(filename) when is_binary(filename) do
    Path.join(media_dir(), filename)
  end

  def media_url(filename) when is_binary(filename) do
    "/media/#{filename}"
  end

  def ensure_media_dir do
    File.mkdir_p!(media_dir())
  end

  @doc """
  Returns dimensions for a named size.
  """
  def size_dimensions(size) do
    Map.get(@sizes, size, {800, 600})
  end

  @doc """
  Returns the full set of standard sizes.
  """
  def sizes, do: @sizes

  @doc """
  Builds a filename like `katherine-liberovskaya-2a-card.webp`
  from a slug, size name, and extension.
  """
  def filename(slug, size, ext) do
    "#{slug}-#{size}#{ext}"
  end

  @doc """
  Builds the full filesystem path for a media variant.
  """
  def path(slug, size, ext) do
    media_path(filename(slug, size, ext))
  end

  @doc """
  Builds the URL path for a media variant.
  """
  def url(slug, size, ext) do
    media_url(filename(slug, size, ext))
  end

  @doc """
  Parses a media filename back into its components.

  Given "katherine-liberovskaya-2a-card.webp", returns:
  {:ok, %{slug: "katherine-liberovskaya-2a", size: "card", ext: ".webp"}}

  Returns :error if the filename doesn't match the expected pattern.
  """
  def parse_filename(filename) do
    case Regex.run(~r/^(.+)-(hero|card|thumb|admin|press)(\.\w+)$/, filename) do
      [_, slug, size, ext] -> {:ok, %{slug: slug, size: size, ext: ext}}
      _ -> :error
    end
  end
end