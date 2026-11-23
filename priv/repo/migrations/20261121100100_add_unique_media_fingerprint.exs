defmodule MykonosBiennale.Repo.Migrations.AddUniqueMediaFingerprint do
  @moduledoc """
  One visible media record per file, URL or embed code. Retired (tombstoned) duplicates
  keep their fingerprint but are excluded from the index. Duplicates that are still
  visible must be merged first with `mix mb.media.dedupe`; this migration stops if any
  remain.
  """
  use Ecto.Migration

  def up do
    %{rows: [[groups]]} =
      repo().query!("""
      SELECT count(*) FROM (
        SELECT fingerprint FROM media
        WHERE fingerprint IS NOT NULL AND visible
        GROUP BY fingerprint HAVING count(*) > 1
      ) duplicates
      """)

    if groups > 0 do
      raise """
      #{groups} duplicate media group(s) are still visible. Run `mix mb.media.dedupe --dry-run`
      to preview, then `mix mb.media.dedupe` to retire them, and migrate again.
      """
    end

    create_index()
  end

  def down do
    drop_if_exists index(:media, [:fingerprint], name: :media_fingerprint_index)
  end

  defp create_index do
    create unique_index(:media, [:fingerprint],
             where: "fingerprint IS NOT NULL AND visible",
             name: :media_fingerprint_index
           )
  end
end
