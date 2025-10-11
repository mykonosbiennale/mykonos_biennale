defmodule MykonosBiennale.Data.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entities" do
    field :identity, :string
    field :slug, :string
    field :visible, :boolean, default: false
    field :fields, :map

    has_many(:as_subject, MykonosBiennale.Data.Relationship, foreign_key: :subject_id)
    has_many(:as_object, MykonosBiennale.Data.Relationship, foreign_key: :object_id)
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entity, attrs, _meta \\ []) do
    entity
    |> cast(attrs, [:identity, :slug, :visible, :fields])
    |> validate_required([:identity, :slug, :visible])
  end
end
