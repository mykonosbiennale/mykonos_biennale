defmodule MykonosBiennale.Search.Transliterate do
  @moduledoc """
  Greek ↔ Latin transliteration and diacritic stripping for search indexing.

  Goals:
    * Strip diacritics on both Greek (έ→ε) and Latin (é→e) text via NFD decomposition.
    * Provide an ASCII-friendly Latin transliteration of Greek words so a search
      for `venieri` will match an entity whose identity is `Λυδία Βενιέρη`.
    * Index both forms (original + transliteration) so searches in either
      script find the same records.
  """

  # Multi-char digraphs come first (longest match wins).
  @digraphs [
    {"ΟΥ", "ou"}, {"Ου", "ou"}, {"ου", "ou"},
    {"ΑΙ", "ai"}, {"Αι", "ai"}, {"αι", "ai"},
    {"ΕΙ", "ei"}, {"Ει", "ei"}, {"ει", "ei"},
    {"ΟΙ", "oi"}, {"Οι", "oi"}, {"οι", "oi"},
    {"ΥΙ", "yi"}, {"Υι", "yi"}, {"υι", "yi"},
    {"ΑΥ", "av"}, {"Αυ", "av"}, {"αυ", "av"},
    {"ΕΥ", "ev"}, {"Ευ", "ev"}, {"ευ", "ev"},
    {"ΗΥ", "iv"}, {"Ηυ", "iv"}, {"ηυ", "iv"},
    {"ΓΓ", "ng"}, {"Γγ", "ng"}, {"γγ", "ng"},
    {"ΓΚ", "g"}, {"Γκ", "g"}, {"γκ", "g"},
    {"ΓΞ", "nx"}, {"Γξ", "nx"}, {"γξ", "nx"},
    {"ΜΠ", "b"}, {"Μπ", "b"}, {"μπ", "b"},
    {"ΝΤ", "d"}, {"Ντ", "d"}, {"ντ", "d"}
  ]

  @single_chars %{
    "Α" => "a", "α" => "a",
    "Β" => "v", "β" => "v",
    "Γ" => "g", "γ" => "g",
    "Δ" => "d", "δ" => "d",
    "Ε" => "e", "ε" => "e",
    "Ζ" => "z", "ζ" => "z",
    "Η" => "i", "η" => "i",
    "Θ" => "th", "θ" => "th",
    "Ι" => "i", "ι" => "i",
    "Κ" => "k", "κ" => "k",
    "Λ" => "l", "λ" => "l",
    "Μ" => "m", "μ" => "m",
    "Ν" => "n", "ν" => "n",
    "Ξ" => "x", "ξ" => "x",
    "Ο" => "o", "ο" => "o",
    "Π" => "p", "π" => "p",
    "Ρ" => "r", "ρ" => "r",
    "Σ" => "s", "σ" => "s", "ς" => "s",
    "Τ" => "t", "τ" => "t",
    "Υ" => "y", "υ" => "y",
    "Φ" => "f", "φ" => "f",
    "Χ" => "ch", "χ" => "ch",
    "Ψ" => "ps", "ψ" => "ps",
    "Ω" => "o", "ω" => "o"
  }

  @doc """
  Returns the input text both stripped of diacritics and a Latin transliteration
  of any Greek text it contains, joined by a space. Both outputs are lowercased.

  ## Examples

      iex> Transliterate.normalize("Λυδία Βενιέρη")
      "λυδια βενιερη lydia venieri"

      iex> Transliterate.normalize("Café")
      "cafe cafe"
  """
  def normalize(nil), do: ""
  def normalize(text) when is_binary(text) do
    stripped = strip_diacritics(text) |> String.downcase()
    transliterated = stripped |> transliterate()

    if stripped == transliterated do
      stripped
    else
      stripped <> " " <> transliterated
    end
  end

  def normalize(other), do: normalize(to_string(other))

  @doc """
  Strips diacritics from text via NFD (canonical decomposition) followed by
  removing all combining marks.
  """
  def strip_diacritics(text) when is_binary(text) do
    text
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}/u, "")
  end

  @doc """
  Transliterates Greek characters to Latin. Latin/other characters are passed
  through. Result is always lowercase.
  """
  def transliterate(text) when is_binary(text) do
    do_translit(text, [])
  end

  defp do_translit("", acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp do_translit(rest, acc) do
    case match_digraph(rest) do
      {match, repl, tail} ->
        do_translit(tail, [repl | acc])

      :nomatch ->
        case String.next_grapheme(rest) do
          {grapheme, tail} ->
            translated = Map.get(@single_chars, grapheme, String.downcase(grapheme))
            do_translit(tail, [translated | acc])

          nil ->
            acc |> Enum.reverse() |> IO.iodata_to_binary()
        end
    end
  end

  defp match_digraph(text) do
    Enum.find_value(@digraphs, :nomatch, fn {prefix, repl} ->
      case text do
        <<^prefix::binary, rest::binary>> -> {prefix, repl, rest}
        _ -> false
      end
    end)
  end
end
