defmodule MykonosBiennale.Content.Media do
  use Ecto.Schema
  import Ecto.Changeset

  schema "media" do
    field :caption, :string
    field :source_type, :string
    field :source_url, :string
    field :source_embed, :string
    field :source_path, :string
    field :mime_type, :string
    field :alt_text, :string
    field :metadata, :map
    field :search_index, :string
    field :search_indexed_at, :naive_datetime

    many_to_many(:entities, MykonosBiennale.Content.Entity,
      join_through: "entity_media",
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(media, attrs) do
    media
    |> cast(attrs, [
      :caption,
      :source_type,
      :source_url,
      :source_embed,
      :source_path,
      :mime_type,
      :alt_text,
      :metadata,
      :search_index,
      :search_indexed_at
    ])
    |> validate_required([:source_type])
    |> validate_inclusion(:source_type, ["upload", "url", "embed"])
    |> validate_source_fields()
  end

  defp validate_source_fields(changeset) do
    source_type = get_field(changeset, :source_type)

    case source_type do
      "upload" ->
        changeset
        |> validate_required([:source_path])
        |> put_change(:source_url, nil)
        |> put_change(:source_embed, nil)

      "url" ->
        changeset
        |> validate_required([:source_url])
        |> validate_url(:source_url)
        |> put_change(:source_path, nil)
        |> put_change(:source_embed, nil)

      "embed" ->
        changeset
        |> validate_required([:source_embed])
        |> put_change(:source_path, nil)
        |> put_change(:source_url, nil)

      _ ->
        changeset
    end
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      uri = URI.parse(url)

      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP or HTTPS URL"}]
      end
    end)
  end
end
