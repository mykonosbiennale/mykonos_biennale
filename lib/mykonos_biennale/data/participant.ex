defmodule MykonosBiennale.Data.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entities" do
    field :identity, :string
    field :slug, :string
    field :visible, :boolean, default: false

    embeds_one :fields, ParticipantFields, on_replace: :update

    has_many(:as_subject, MykonosBiennale.Data.Relationship, foreign_key: :subject_id)
    has_many(:as_object, MykonosBiennale.Data.Relationship, foreign_key: :object_id)
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(entity, attrs, _meta \\ []) do
    entity
    |> cast(attrs, [:identity, :slug, :visible])
    |> validate_required([:identity, :slug, :visible, :fields])
    |> cast_embed(:fields,
      with: &ParticipantFields.changeset/2,
      required: true,
      force_update_on_change: true
    )
  end
end

defmodule ParticipantFields do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, :string, default: "participant"
    field :email, :string
    field :phone, :string
  end

  @doc false
  def changeset(fields, attrs \\ %{}) do
    fields
    |> cast(attrs, [:type, :phone, :email])
    |> validate_required([:type, :phone, :email])

    # |> validate_format(:email, ~r/@/)
    #     |> validate_format(:phone, ~r/\d{3}-\d{3}-\d{4}/)
    #     |> validate_length(:email, max: 255)
    #     |> validate_length(:phone, max: 20)
    #     |> validate_length(:type, max: 255)
  end
end
