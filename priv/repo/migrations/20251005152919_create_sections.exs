defmodule MykonosBiennale.Repo.Migrations.CreateSections do
  use Ecto.Migration

  def change do
    create table(:sections) do
      add :title, :string
      add :slug, :string
      add :description, :string
      add :template, :string
      add :content, :string
      add :visible, :boolean, default: false, null: false
      add :metadata, :map
      add :page_id, references(:pages, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sections, [:page_id])
  end
end
