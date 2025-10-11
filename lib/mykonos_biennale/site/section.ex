defmodule MykonosBiennale.Site.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    field :position, :integer
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
  def changeset(section, attrs, _meta \\ []) do
    section
    |> cast(attrs, [
      :position,
      :title,
      :slug,
      :description,
      :template,
      :content,
      :visible,
      :metadata,
      :page_id
    ])
    |> maybe_generate_position()
    |> validate_required([:position, :title, :slug, :template, :content, :visible, :page_id])
  end

  def maybe_generate_position(changeset) do
    changeset
    |> Ecto.Changeset.get_field(:position)
    |> case do
      nil ->
        Ecto.Changeset.put_change(
          changeset,
          :position,
          MykonosBiennale.Repo.aggregate(__MODULE__, :count, :id) + 1
        )

      _otherwise ->
        changeset
    end
  end
end
