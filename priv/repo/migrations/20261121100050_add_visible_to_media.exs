defmodule MykonosBiennale.Repo.Migrations.AddVisibleToMedia do
  use Ecto.Migration

  def change do
    alter table(:media) do
      add :visible, :boolean, default: true, null: false
    end
  end
end
