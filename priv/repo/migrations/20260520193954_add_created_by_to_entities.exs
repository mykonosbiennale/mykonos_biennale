defmodule MykonosBiennale.Repo.Migrations.AddCreatedByToEntities do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :created_by_id, references(:users, on_delete: :restrict)
    end

    create index(:entities, [:created_by_id])
  end
end
