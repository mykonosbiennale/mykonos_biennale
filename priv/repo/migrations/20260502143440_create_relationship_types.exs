defmodule MykonosBiennale.Repo.Migrations.CreateRelationshipTypes do
  use Ecto.Migration

  def up do
    create table(:relationship_types) do
      add :label, :string, null: false
      add :slug, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:relationship_types, [:slug])

    alter table(:relationships) do
      add :relationship_type_id, references(:relationship_types, on_delete: :nothing)
    end

    execute """
    INSERT INTO relationship_types (label, slug, inserted_at, updated_at)
    SELECT DISTINCT name, slug, datetime('now'), datetime('now')
    FROM relationships
    WHERE name IS NOT NULL AND slug IS NOT NULL
    """

    execute """
    UPDATE relationships
    SET relationship_type_id = (
      SELECT rt.id FROM relationship_types rt
      WHERE rt.slug = relationships.slug AND rt.label = relationships.name
    )
    """

    execute "DROP INDEX IF EXISTS relationship_index"

    alter table(:relationships) do
      remove :name
      remove :slug
    end

    create unique_index(:relationships, [:subject_id, :relationship_type_id, :object_id],
             name: :relationship_index
           )
  end

  def down do
    alter table(:relationships) do
      add :name, :string
      add :slug, :string
    end

    execute """
    UPDATE relationships
    SET name = (SELECT rt.label FROM relationship_types rt WHERE rt.id = relationships.relationship_type_id),
        slug = (SELECT rt.slug FROM relationship_types rt WHERE rt.id = relationships.relationship_type_id)
    """

    execute "DROP INDEX IF EXISTS relationship_index"

    create unique_index(:relationships, [:subject_id, :slug, :object_id],
             name: :relationship_index
           )

    alter table(:relationships) do
      remove :relationship_type_id
    end

    drop table(:relationship_types)
  end
end
