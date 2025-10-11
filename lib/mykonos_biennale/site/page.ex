defmodule MykonosBiennale.Site.Page do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pages" do
    field :position, :integer
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
  def changeset(page, attrs, _meta \\ []) do
    page
    |> cast(attrs, [
      :position,
      :title,
      :slug,
      :description,
      :template,
      :content,
      :visible,
      :metadata
    ])
    |> maybe_generate_position()
    |> validate_required([:position, :title, :slug, :template, :content, :visible])
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
