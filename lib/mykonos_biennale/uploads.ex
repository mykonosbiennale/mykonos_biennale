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
end