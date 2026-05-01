defmodule MykonosBiennale.Content.EntityMedia do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "entity_media" do
    belongs_to :entity, MykonosBiennale.Content.Entity, primary_key: true
    belongs_to :media, MykonosBiennale.Content.Media, primary_key: true

    field :position, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(entity_media, attrs) do
    entity_media
    |> cast(attrs, [:entity_id, :media_id, :position, :metadata])
    |> validate_required([:entity_id, :media_id])
  end
end
