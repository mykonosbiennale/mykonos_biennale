defmodule MykonosBiennale.Search do
  @moduledoc """
  Public search API. Performs a normalized substring match against the
  `search_index` column on entities and media, resolves each hit to a public
  URL, and groups results by kind.

  Index population is the responsibility of `MykonosBiennale.Search.Indexer`
  and `MykonosBiennale.Workers.SearchReindex`.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.{Entity, Media, EntityMedia}
  alias MykonosBiennale.Search.Transliterate

  @type hit :: %{
          kind: atom(),
          id: integer(),
          title: String.t(),
          subtitle: String.t() | nil,
          url: String.t(),
          snippet: String.t()
        }

  @default_limit 50

  @doc """
  Search for entities and media matching `term`. Returns a map:

      %{
        entities: [hit, ...],
        media: [hit, ...],
        total: integer
      }

  Options:

    * `:limit` - maximum hits per kind (default #{@default_limit})
    * `:types` - list of entity types to restrict to
  """
  def search(term, opts \\ [])

  def search(term, _opts) when not is_binary(term) or term == "" do
    %{entities: [], media: [], total: 0}
  end

  def search(term, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    types = Keyword.get(opts, :types)

    normalized = Transliterate.normalize(term)
    pattern = "%" <> normalized <> "%"

    entities = search_entities(pattern, types, limit)
    media = search_media(pattern, limit)

    biennale_year_by_id = build_biennale_year_lookup(entities)
    media_owner_by_id = build_media_owner_lookup(media)

    entity_hits = Enum.map(entities, &entity_to_hit(&1, biennale_year_by_id, normalized))

    media_hits =
      Enum.map(media, &media_to_hit(&1, media_owner_by_id, biennale_year_by_id, normalized))

    %{
      entities: entity_hits,
      media: media_hits,
      total: length(entity_hits) + length(media_hits)
    }
  end

  @doc """
  Helper for admin LiveViews and other internal consumers — returns a single
  Ecto query that filters entities by `search_index LIKE ?`. Useful for
  preserving stream/order semantics in the existing admin UIs.
  """
  def entity_search_pattern(term) when is_binary(term) and term != "" do
    "%" <> Transliterate.normalize(term) <> "%"
  end

  def entity_search_pattern(_), do: nil

  # =====================================================================
  # Private — querying
  # =====================================================================

  defp search_entities(pattern, types, limit) do
    query =
      from e in Entity,
        where: not is_nil(e.search_index) and like(e.search_index, ^pattern),
        limit: ^limit,
        order_by: [asc: fragment("length(?)", e.search_index)]

    query =
      case types do
        nil -> query
        list when is_list(list) -> from e in query, where: e.type in ^list
      end

    Repo.all(query)
  end

  defp search_media(pattern, limit) do
    Repo.all(
      from m in Media,
        where: not is_nil(m.search_index) and like(m.search_index, ^pattern),
        limit: ^limit,
        order_by: [asc: fragment("length(?)", m.search_index)]
    )
  end

  # =====================================================================
  # Private — biennale-year resolution for URL building
  # =====================================================================

  # For each entity in `entities`, fetch a biennale year via the indexed
  # tokens. We rely on the indexer to have written `rel.biennale_year:YEAR`
  # tokens — this means we can resolve URLs without re-running graph queries
  # at search time.
  defp build_biennale_year_lookup(entities) do
    Map.new(entities, fn entity ->
      {entity.id, extract_biennale_year(entity.search_index)}
    end)
  end

  defp extract_biennale_year(nil), do: nil

  defp extract_biennale_year(index) when is_binary(index) do
    # tokens are space-joined; biennale year token looks like "rel.biennale_year:2023"
    Regex.scan(~r/rel\.biennale_year:(\d{4})/, index)
    |> Enum.map(fn [_, y] -> y end)
    |> Enum.uniq()
    |> Enum.sort(:desc)
    |> List.first()
  end

  # For each media, find the first attached entity (by position) so we can
  # link the media to the entity's public page.
  defp build_media_owner_lookup([]), do: %{}

  defp build_media_owner_lookup(media) do
    media_ids = Enum.map(media, & &1.id)

    rows =
      Repo.all(
        from em in EntityMedia,
          join: e in Entity,
          on: e.id == em.entity_id,
          where: em.media_id in ^media_ids,
          order_by: em.position,
          select: {em.media_id, e}
      )

    Enum.reduce(rows, %{}, fn {mid, entity}, acc ->
      Map.put_new(acc, mid, entity)
    end)
  end

  # =====================================================================
  # Private — hit construction
  # =====================================================================

  defp entity_to_hit(%Entity{} = entity, year_lookup, normalized) do
    %{
      kind: :entity,
      id: entity.id,
      title: entity_title(entity),
      subtitle: entity_subtitle(entity, year_lookup),
      url: entity_url(entity, year_lookup),
      snippet: snippet(entity.search_index, normalized)
    }
  end

  defp media_to_hit(%Media{} = media, owner_lookup, year_lookup, normalized) do
    owner = Map.get(owner_lookup, media.id)

    %{
      kind: :media,
      id: media.id,
      title: media_title(media, owner),
      subtitle: media_subtitle(media, owner),
      url: media_url(media, owner, year_lookup),
      snippet: snippet(media.search_index, normalized)
    }
  end

  defp entity_title(%Entity{type: "biennale", fields: %{"year" => y}}),
    do: "Mykonos Biennale #{y}"

  defp entity_title(%Entity{identity: id}) when is_binary(id) and id != "", do: id

  defp entity_title(%Entity{fields: fields}) when is_map(fields) do
    Map.get(fields, "title") || Map.get(fields, "name") || compose_name(fields) || "Untitled"
  end

  defp entity_title(_), do: "Untitled"

  defp compose_name(fields) when is_map(fields) do
    first = Map.get(fields, "first_name", "")
    last = Map.get(fields, "last_name", "")
    name = String.trim("#{first} #{last}")
    if name == "", do: nil, else: name
  end

  defp compose_name(_), do: nil

  defp entity_subtitle(%Entity{type: type} = entity, year_lookup) do
    base = humanize_type(type)
    year = Map.get(year_lookup, entity.id)

    cond do
      type == "biennale" -> "Biennale Edition"
      year -> "#{base} · #{year}"
      true -> base
    end
  end

  defp humanize_type("Short Film"), do: "Short Film"
  defp humanize_type("Video"), do: "Video"
  defp humanize_type("Dance"), do: "Dance"
  defp humanize_type("Animation"), do: "Animation"
  defp humanize_type("Documentary"), do: "Documentary"
  defp humanize_type(t) when is_binary(t), do: String.capitalize(t)
  defp humanize_type(_), do: ""

  # The site only has dead public pages: /, /archive, /archive/:year, /program, /about.
  # Map every entity to the closest aggregate page.
  defp entity_url(%Entity{type: "biennale", fields: %{"year" => y}}, _), do: "/archive/#{y}"

  defp entity_url(%Entity{} = entity, year_lookup) do
    case Map.get(year_lookup, entity.id) do
      nil -> "/archive"
      year -> "/archive/#{year}"
    end
  end

  defp media_title(%Media{caption: caption}, _) when is_binary(caption) and caption != "",
    do: caption

  defp media_title(_, %Entity{} = owner), do: "Image · #{entity_title(owner)}"
  defp media_title(_, _), do: "Untitled media"

  defp media_subtitle(_, %Entity{} = owner), do: "Media in #{humanize_type(owner.type)}"
  defp media_subtitle(_, _), do: "Media"

  defp media_url(_, %Entity{} = owner, year_lookup), do: entity_url(owner, year_lookup)
  defp media_url(_, _, _), do: "/archive"

  # =====================================================================
  # Private — snippet extraction
  # =====================================================================

  @snippet_window 80

  defp snippet(nil, _term), do: ""
  defp snippet(_index, ""), do: ""

  defp snippet(index, term) do
    case String.split(term, " ", trim: true) do
      [] ->
        ""

      tokens ->
        # Find the earliest-occurring matching token in the index.
        case earliest_index(index, tokens) do
          nil ->
            String.slice(strip_section_prefixes(index), 0, @snippet_window)

          {pos, len} ->
            extract_window(strip_section_prefixes(index), pos, len)
        end
    end
  end

  defp earliest_index(haystack, tokens) do
    tokens
    |> Enum.map(fn t ->
      case :binary.match(haystack, t) do
        {pos, _len} -> {pos, byte_size(t)}
        :nomatch -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      list -> Enum.min_by(list, fn {pos, _} -> pos end)
    end
  end

  defp extract_window(text, pos, len) do
    half = div(@snippet_window, 2)
    start = max(0, pos - half)
    snippet = String.slice(text, start, @snippet_window)
    prefix = if start > 0, do: "…", else: ""
    suffix = if start + @snippet_window < String.length(text), do: "…", else: ""

    (prefix <> snippet <> suffix)
    |> String.trim()
    |> elide_unrelated()
    |> ensure_match_visible(len)
  end

  defp elide_unrelated(s), do: s

  defp ensure_match_visible(s, _len), do: s

  # Strip the "section:" prefixes from indexed tokens for display, e.g.
  # "field.title:garden of mysteries" -> "garden of mysteries".
  defp strip_section_prefixes(text) do
    text
    |> String.split(" ", trim: true)
    |> Enum.map(fn token ->
      case String.split(token, ":", parts: 2) do
        [_label, value] -> value
        [value] -> value
      end
    end)
    |> Enum.join(" ")
  end
end
