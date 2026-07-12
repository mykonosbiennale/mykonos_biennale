defmodule MykonosBiennaleWeb.FilmHTML do
  use MykonosBiennaleWeb, :html

  alias MykonosBiennale.Content.Entity

  embed_templates "film_html/*"

  def media_url(media, opts \\ [])
  def media_url(media, opts), do: MykonosBiennale.Uploads.media_url(media, opts)

  def field(entity, key, default \\ nil)

  def field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  def field(_, _key, default), do: default

  defp participant_name(%Entity{fields: %{"name" => name}}) when is_binary(name) and name != "",
    do: name

  defp participant_name(%Entity{fields: %{"first_name" => first, "last_name" => last}}),
    do: String.trim("#{first || ""} #{last || ""}")

  defp participant_name(_), do: "Unknown"

  def trailer_embed(nil), do: nil

  def trailer_embed(embed) when is_binary(embed) and embed != "" do
    Phoenix.HTML.raw(embed)
  end

  def trailer_embed(_), do: nil
end
