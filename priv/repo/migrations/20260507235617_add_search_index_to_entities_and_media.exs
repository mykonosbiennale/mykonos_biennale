defmodule MykonosBiennale.Repo.Migrations.AddSearchIndexToEntitiesAndMedia do
  use Ecto.Migration

  def change do
    alter table(:entities) do
      add :search_index, :text
      add :search_indexed_at, :naive_datetime
    end

    alter table(:media) do
      add :search_index, :text
      add :search_indexed_at, :naive_datetime
    end
  end
end
