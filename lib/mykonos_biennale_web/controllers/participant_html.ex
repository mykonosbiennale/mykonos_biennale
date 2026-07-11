defmodule MykonosBiennaleWeb.ParticipantHTML do
  use MykonosBiennaleWeb, :html

  alias MykonosBiennale.Content.Entity

  embed_templates "participant_html/*"

  def media_url(media, opts \\ [])
  def media_url(media, opts), do: MykonosBiennale.Uploads.media_url(media, opts)

  defp field(entity, key, default \\ nil)

  defp field(%Entity{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp field(_, _key, default), do: default

  defp participant_name(%Entity{fields: %{"name" => name}}) when is_binary(name) and name != "",
    do: name

  defp participant_name(%Entity{fields: %{"first_name" => first, "last_name" => last}}),
    do: String.trim("#{first || ""} #{last || ""}")

  defp participant_name(_), do: "Unknown"
end
