defmodule MykonosBiennale.Repo.Migrations.NormalizeFilmTitlesInFields do
  use Ecto.Migration

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  def up do
    # Set fields.title = identity for all films missing a title in fields
    execute """
      UPDATE entities
      SET fields = fields || jsonb_build_object('title', identity)
      WHERE type IN ('#{Enum.join(@film_types, "','")}')
        AND NOT fields ? 'title'
    """
  end

  def down do
    # Remove the title key we added (only if it matches identity, to be safe)
    execute """
      UPDATE entities
      SET fields = fields - 'title'
      WHERE type IN ('#{Enum.join(@film_types, "','")}')
        AND fields ? 'title'
        AND fields->>'title' = identity
    """
  end
end
