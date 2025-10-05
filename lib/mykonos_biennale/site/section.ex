defmodule MykonosBiennale.Site.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :template, Ecto.Enum, values: [:none, :default]
    field :content, :string
    field :visible, :boolean, default: false
    field :metadata, :map, default: %{}
    belongs_to :page, MykonosBiennale.Site.Page

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(section, attrs, meta \\ []) do
    section
    |> cast(attrs, [
      :title,
      :slug,
      :description,
      :template,
      :content,
      :visible,
      :metadata,
      :page_id
    ])
    |> validate_required([:title, :slug, :template, :content, :visible, :page_id])
  end
end
