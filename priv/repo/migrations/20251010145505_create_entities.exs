defmodule MykonosBiennale.Repo.Migrations.CreateEntities do
  use Ecto.Migration

  def change do
    create table(:entities) do
      add :identity, :string
      add :slug, :string
      add :visible, :boolean, default: false, null: false
      add :fields, :map

      timestamps(type: :utc_datetime)
    end
  end
end
