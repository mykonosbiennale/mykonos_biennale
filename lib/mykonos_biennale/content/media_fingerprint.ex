defmodule MykonosBiennale.Content.MediaFingerprint do
  @moduledoc """
  A stable identity for a media item. Two media records with the same fingerprint are
  the same media, so only one record is kept and every entity links to it.

    * uploads: `sha256:<hex>` of the file bytes. A rotated or re-encoded copy is a
      different file, so it gets its own fingerprint.
    * URLs: `url:<trimmed url>`
    * embed codes: `embed:<sha256 of the trimmed code>`

  Returns `nil` when a fingerprint cannot be computed (for example an upload whose file
  is missing from disk). Such media is never treated as a duplicate.
  """

  alias Ecto.Changeset
  alias MykonosBiennale.Uploads

  @doc "Fingerprint for a valid media changeset, or nil."
  def for_changeset(%Changeset{valid?: true} = changeset) do
    for_fields(
      Changeset.get_field(changeset, :source_type),
      Changeset.get_field(changeset, :source_path),
      Changeset.get_field(changeset, :source_url),
      Changeset.get_field(changeset, :source_embed)
    )
  end

  def for_changeset(_changeset), do: nil

  @doc "Fingerprint for a stored media record, or nil."
  def for_media(%{source_type: type, source_path: path, source_url: url, source_embed: embed}) do
    for_fields(type, path, url, embed)
  end

  defp for_fields("upload", path, _url, _embed) when is_binary(path) do
    case sha256_file(Uploads.uploads_path(path)) do
      {:ok, digest} -> "sha256:" <> digest
      {:error, _reason} -> nil
    end
  end

  defp for_fields("url", _path, url, _embed) when is_binary(url) do
    "url:" <> String.trim(url)
  end

  defp for_fields("embed", _path, _url, embed) when is_binary(embed) do
    "embed:" <> sha256_text(String.trim(embed))
  end

  defp for_fields(_type, _path, _url, _embed), do: nil

  defp sha256_text(text) do
    :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
  end

  # Streams the file so large videos are never read into memory at once.
  defp sha256_file(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, io} ->
        digest = hash_chunks(io, :crypto.hash_init(:sha256))
        File.close(io)
        {:ok, digest |> :crypto.hash_final() |> Base.encode16(case: :lower)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hash_chunks(io, state) do
    case IO.binread(io, 1_048_576) do
      data when is_binary(data) -> hash_chunks(io, :crypto.hash_update(state, data))
      _eof -> state
    end
  end
end
