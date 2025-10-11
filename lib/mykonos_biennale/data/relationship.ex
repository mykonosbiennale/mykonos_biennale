defmodule MykonosBiennale.Data.Relationship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "relationships" do
    field :name, :string
    field :slug, :string
    field :fields, :map

    belongs_to(:subject, MykonosBiennale.Data.Entity,
      foreign_key: :subject_id,
      on_replace: :update
    )

    belongs_to(:object, MykonosBiennale.Data.Entity, foreign_key: :object_id, on_replace: :update)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(relationship, attrs, _meta \\ []) do
    relationship
    |> cast(attrs, [:name, :slug, :fields, :subject_id, :object_id])
    |> validate_required([:name, :slug, :subject_id, :object_id])
    |> unique_constraint([:subject_id, :slug, :object_id], name: :relationship_index)
  end
end
