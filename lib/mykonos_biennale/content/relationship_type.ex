defmodule MykonosBiennale.Content.RelationshipType do
  @moduledoc """
  RelationshipType-specific operations within the Content context.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo

  schema "relationship_types" do
    field :label, :string
    field :slug, :string

    has_many :relationships, MykonosBiennale.Content.Relationship

    timestamps(type: :utc_datetime)
  end

  def list do
    Repo.all(from rt in __MODULE__, order_by: [asc: rt.slug])
  end

  def get!(id), do: Repo.get!(__MODULE__, id)

  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Repo.insert()
  end

  def update(%__MODULE__{} = relationship_type, attrs) do
    relationship_type
    |> changeset(attrs)
    |> Repo.update()
  end

  def delete(%__MODULE__{} = relationship_type) do
    Repo.delete(relationship_type)
  end

  def changeset(%__MODULE__{} = relationship_type, attrs) do
    relationship_type
    |> cast(attrs, [:label, :slug])
    |> validate_required([:label, :slug])
    |> unique_constraint(:slug)
  end
end
