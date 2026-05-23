defmodule MykonosBiennale.MediaSlug do
  @moduledoc """
  Generates SEO-friendly slugs for media records.

  Format: `{slug_from_caption_or_original_name}-{base62_id}`

  Examples:
    "katherine-liberovskaya-2a"
    "2021-biennale-opening-night-4g"
    "media-1i"
  """

  @slug_regex ~r/[^a-z0-9]+/

  @doc """
  Generates a slug from a caption or original name, combined with the media ID.

  The slug is deterministic: same inputs always produce the same slug.
  """
  def generate(id, caption \\ nil, original_name \\ nil) do
    base = pick_base(caption, original_name)

    base
    |> String.downcase()
    |> String.replace(@slug_regex, "-")
    |> String.replace(~r/^-|-$/, "")
    |> String.slice(0, 60)
    |> ensure_nonempty()
    |> Kernel.<>("-" <> encode_id(id))
  end

  @doc """
  Extracts the media ID from a slug by decoding the base62 suffix.
  Returns nil if the slug format is invalid.
  """
  def extract_id(slug) do
    case String.split(slug, "-", parts: :infinity) do
      parts when length(parts) >= 2 ->
        parts
        |> List.last()
        |> decode_id()

      _ ->
        nil
    end
  end

  defp pick_base(caption, _original_name) when is_binary(caption) and caption != "", do: caption
  defp pick_base(_caption, original_name) when is_binary(original_name) and original_name != "", do: original_name
  defp pick_base(_, _), do: "media"

  defp ensure_nonempty(""), do: "media"
  defp ensure_nonempty(s), do: s

  @chars ~c"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

  def encode_id(id) when is_integer(id) and id > 0 do
    id |> encode_base62([]) |> List.to_string()
  end

  defp encode_base62(0, acc), do: [Enum.at(@chars, 0) | acc]
  defp encode_base62(id, acc) do
    encode_base62(div(id, 62), [Enum.at(@chars, rem(id, 62)) | acc])
  end

  def decode_id(encoded) when is_binary(encoded) do
    encoded
    |> String.to_charlist()
    |> Enum.reduce(0, fn char, acc ->
      case Enum.find_index(@chars, &(&1 == char)) do
        nil -> -1
        idx -> acc * 62 + idx
      end
    end)
  end

  def decode_id(_), do: nil
end