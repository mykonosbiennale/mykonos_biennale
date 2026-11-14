defmodule MykonosBiennale.Repo.Migrations.AddBiennaleSponsorRelationshipType do
  use Ecto.Migration

  def up do
    execute """
      INSERT INTO relationship_types (slug, label, inserted_at, updated_at)
      VALUES ('biennale_sponsor', 'sponsor', NOW(), NOW())
      ON CONFLICT (slug) DO NOTHING
    """
  end

  def down do
    execute "DELETE FROM relationship_types WHERE slug = 'biennale_sponsor'"
  end
end
