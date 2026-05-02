defmodule MykonosBiennale.Content.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "relationships" do
    field :fields, :map

    belongs_to(:relationship_type, MykonosBiennale.Content.RelationshipType)

    belongs_to(:subject, MykonosBiennale.Content.Entity,
      foreign_key: :subject_id,
      on_replace: :update
    )

    belongs_to(:object, MykonosBiennale.Content.Entity,
      foreign_key: :object_id,
      on_replace: :update
    )

    timestamps(type: :utc_datetime)
  end

  def changeset(relationship, attrs, _meta \\ []) do
    relationship
    |> cast(attrs, [:fields, :relationship_type_id, :subject_id, :object_id])
    |> validate_required([:relationship_type_id, :subject_id, :object_id])
    |> unique_constraint([:subject_id, :relationship_type_id, :object_id],
      name: :relationship_index
    )
  end
end
