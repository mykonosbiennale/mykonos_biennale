defmodule MykonosBiennale.Repo.Migrations.AddSeoToEntities do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :seo, :map, null: false, default: %{}
    end
  end
end
