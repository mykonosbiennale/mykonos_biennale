defmodule MykonosBiennale.Repo.Migrations.CreatePages do
  use Ecto.Migration

  def change do
    create table(:pages) do
      add :title, :string
      add :slug, :string
      add :description, :text
      add :template, :string
      add :content, :text
      add :visible, :boolean, default: false, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end
  end
end
