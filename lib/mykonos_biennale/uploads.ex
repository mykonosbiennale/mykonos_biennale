defmodule MykonosBiennale.Uploads do
  @moduledoc """
  Centralized upload path configuration.

  In development, uploads are stored in priv/static/uploads.
  In production, they are stored on the persistent volume at /data/uploads.
  """

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

  def media_url(%{source_type: "upload", source_path: path}, opts \\ []) when is_binary(path) do
    size = Keyword.get(opts, :size, "card")
    ext = Path.extname(path) |> String.downcase()
    basename = Path.basename(path, Path.extname(path))

    if ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff", ".tif"] do
      "/media/#{size}/#{basename}#{ext}"
    else
      "/uploads/#{path}"
    end
  end

  def media_url(%{source_type: "url", source_url: url}, _opts) when is_binary(url), do: url
  def media_url(_, _opts), do: nil
end