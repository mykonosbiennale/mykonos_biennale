defmodule MykonosBiennale.Repo.Migrations.AddFingerprintToMedia do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :fingerprint, :string
    end
  end
end
