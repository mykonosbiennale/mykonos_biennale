defmodule MykonosBiennale.Repo.Migrations.AddMediaOriginalNameAndSlug do
  use Ecto.Migration

  def up do
    alter table(:media) do
      add_if_not_exists :original_name, :string
      add_if_not_exists :slug, :string
    end

    create_if_not_exists unique_index(:media, [:slug])
  end

  def down do
    alter table(:media) do
      remove_if_exists :original_name, :string
      remove_if_exists :slug, :string
    end

    drop_if_exists index(:media, [:slug])
  end
end
