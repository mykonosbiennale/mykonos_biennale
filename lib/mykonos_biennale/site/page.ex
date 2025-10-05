defmodule MykonosBiennale.Site.Page do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pages" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :template, Ecto.Enum, values: [:none, :default]
    field :content, :string
    field :visible, :boolean, default: false
    field :metadata, :map, default: %{}
    has_many :sections, MykonosBiennale.Site.Section, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs, meta \\ []) do
    page
    |> cast(attrs, [:title, :slug, :description, :template, :content, :visible, :metadata])
    |> validate_required([:title, :slug, :template, :content, :visible])
  end
end
