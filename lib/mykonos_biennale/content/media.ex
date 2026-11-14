defmodule MykonosBiennale.Content.Media do
  use Ecto.Schema
  import Ecto.Changeset
  alias MykonosBiennale.MediaSlug

  schema "media" do
    field :caption, :string
    field :source_type, :string
    field :source_url, :string
    field :source_embed, :string
    field :source_path, :string
    field :original_name, :string
    field :slug, :string
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
      :original_name,
      :slug,
      :mime_type,
      :alt_text,
      :metadata,
      :search_index,
      :search_indexed_at
    ])
    |> validate_required([:source_type])
    |> validate_inclusion(:source_type, ["upload", "url", "embed"])
    |> maybe_generate_slug()
    |> validate_source_fields()
  end

  # For new records, id is nil — slug will be set after insert.
  defp maybe_generate_slug(changeset) do
    with nil <- get_field(changeset, :slug),
         "upload" <- get_field(changeset, :source_type),
         source_path when not is_nil(source_path) <- get_field(changeset, :source_path),
         id when not is_nil(id) <- get_field(changeset, :id) do
      put_change(
        changeset,
        :slug,
        MediaSlug.generate(
          id,
          get_field(changeset, :caption),
          get_field(changeset, :original_name)
        )
      )
    else
      _ -> changeset
    end
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
