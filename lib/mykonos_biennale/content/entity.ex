defmodule MykonosBiennale.Content.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entities" do
    field :identity, :string
    field :type, :string
    field :slug, :string
    field :visible, :boolean, default: false
    field :template, Ecto.Enum, values: [:none, :default], default: :default
    field :fields, :map
    field :search_index, :string
    field :search_indexed_at, :naive_datetime

    belongs_to :created_by, MykonosBiennale.Accounts.User

    has_many(:as_subject, MykonosBiennale.Content.Relationship, foreign_key: :subject_id)
    has_many(:as_object, MykonosBiennale.Content.Relationship, foreign_key: :object_id)

    many_to_many(:media, MykonosBiennale.Content.Media,
      join_through: "entity_media",
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entity, attrs, _meta \\ []) do
    entity
    |> cast(attrs, [
      :identity,
      :type,
      :slug,
      :visible,
      :template,
      :fields,
      :search_index,
      :search_indexed_at,
      :created_by_id
    ])
    |> validate_required([:identity, :type, :slug, :visible])
  end
end
