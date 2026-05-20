defmodule MykonosBiennale.Repo.Migrations.AddCreatedByToEntities do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :created_by, references(:users, on_delete: :nilify_all)
    end
  end
end