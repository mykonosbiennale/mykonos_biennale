defmodule MykonosBiennale.Repo.Migrations.AddEventFestivalRelationshipType do
  use Ecto.Migration

  def up do
    execute ~s"""
    INSERT INTO relationship_types (slug, label, inserted_at, updated_at)
    VALUES ('event_festival', 'part_of', NOW(), NOW())
    ON CONFLICT (slug) DO NOTHING
    """
  end

  def down do
    execute ~s"""
    DELETE FROM relationship_types WHERE slug = 'event_festival'
    """
  end
end
