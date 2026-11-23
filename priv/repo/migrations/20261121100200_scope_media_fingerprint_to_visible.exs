defmodule MykonosBiennale.Repo.Migrations.ScopeMediaFingerprintToVisible do
  @moduledoc """
  Databases that ran the earlier unique index (over all rows) get it rebuilt so that
  retired duplicates are excluded. Fresh databases already have the right index.
  """
  use Ecto.Migration

  def up do
    drop_if_exists index(:media, [:fingerprint], name: :media_fingerprint_index)

    create unique_index(:media, [:fingerprint],
             where: "fingerprint IS NOT NULL AND visible",
             name: :media_fingerprint_index
           )
  end

  def down do
    drop_if_exists index(:media, [:fingerprint], name: :media_fingerprint_index)

    create unique_index(:media, [:fingerprint],
             where: "fingerprint IS NOT NULL",
             name: :media_fingerprint_index
           )
  end
end
