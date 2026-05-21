defmodule MykonosBiennale.Repo.Migrations.CreateAllTables do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :role, :string, default: "participant", null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:entities) do
      add :identity, :string
      add :type, :string
      add :slug, :string
      add :visible, :boolean, default: false
      add :template, :string, default: "default", null: false
      add :fields, :map
      add :search_index, :text
      add :search_indexed_at, :naive_datetime
      add :created_by_id, references(:users, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:entities, [:created_by_id])

    create table(:media) do
      add :caption, :text
      add :source_type, :string, null: false
      add :source_url, :string
      add :source_embed, :text
      add :source_path, :string
      add :mime_type, :string
      add :alt_text, :string
      add :metadata, :map, default: %{}
      add :search_index, :text
      add :search_indexed_at, :naive_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:media, [:source_type])

    create table(:entity_media) do
      add :entity_id, references(:entities, on_delete: :delete_all), null: false
      add :media_id, references(:media, on_delete: :delete_all), null: false
      add :position, :integer, default: 0, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:entity_media, [:entity_id])
    create index(:entity_media, [:media_id])
    create unique_index(:entity_media, [:entity_id, :media_id])
    create index(:entity_media, [:entity_id, :position])

    create table(:relationship_types) do
      add :label, :string, null: false
      add :slug, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:relationship_types, [:slug])

    create table(:relationships) do
      add :fields, :map
      add :relationship_type_id, references(:relationship_types, on_delete: :nothing)
      add :subject_id, references(:entities, on_delete: :nothing)
      add :object_id, references(:entities, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:relationships, [:subject_id])
    create index(:relationships, [:object_id])
    create unique_index(:relationships, [:subject_id, :relationship_type_id, :object_id],
             name: :relationship_index
           )

    create table(:pages) do
      add :position, :integer
      add :title, :string
      add :slug, :string
      add :description, :text
      add :template, :string
      add :content, :text
      add :visible, :boolean, default: false, null: false
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create table(:sections) do
      add :position, :integer
      add :title, :string
      add :slug, :string
      add :description, :text
      add :template, :string
      add :content, :text
      add :visible, :boolean, default: false, null: false
      add :metadata, :map
      add :page_id, references(:pages, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:sections, [:page_id])

    Oban.Migration.up()
  end

  def down do
    Oban.Migration.down(version: 1)

    drop table(:sections)
    drop table(:pages)
    drop table(:relationships)
    drop table(:relationship_types)
    drop table(:entity_media)
    drop table(:media)
    drop table(:entities)
    drop table(:users_tokens)
    drop table(:users)

    execute "DROP EXTENSION IF EXISTS citext"
  end
end