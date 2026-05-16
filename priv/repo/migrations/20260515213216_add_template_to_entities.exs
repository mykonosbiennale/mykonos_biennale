defmodule MykonosBiennale.Repo.Migrations.AddTemplateToEntities do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :template, :string, default: "default", null: false
    end
  end
end
