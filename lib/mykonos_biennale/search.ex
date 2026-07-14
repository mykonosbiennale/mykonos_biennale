defmodule MykonosBiennale.Search do
  @moduledoc """
  Public search API. Performs word-boundary + prefix matching against the
  `search_index` column on entities, grouped by type.

  Index population is the responsibility of `MykonosBiennale.Search.Indexer`
  and `MykonosBiennale.Workers.SearchReindex`.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Search.Transliterate

  @type hit :: %{
          kind: atom(),
          id: integer(),
          title: String.t(),
          subtitle: String.t() | nil,
          url: String.t(),
          snippet: String.t(),
          creators: [String.t()],
          events: [String.t()]
        }

  @default_limit 20

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @doc """
  Search for entities matching `term`, grouped by type. Returns a map:

      %{
        biennales: [hit, ...],
        events: [hit, ...],
        participants: [hit, ...],
        works: [hit, ...],
        total: integer
      }

  Options:
    * `:limit` - maximum hits per group (default #{@default_limit})
  """
  def search(term, opts \\ [])

  def search(term, _opts) when not is_binary(term) or term == "" do
    %{biennales: [], events: [], participants: [], works: [], total: 0}
  end

  def search(term, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    _normalized = Transliterate.normalize(term)
    # normalize() returns both Greek and Latin forms joined by spaces.
    # For a single source word like "Βενιέρη", it returns "βενιερη venieri"
    # — these are alternatives (OR), not both required (AND).
    # For actual multi-word queries like "anna molloy", each word normalizes
    # independently and all must match (AND).
    #
    # Strategy: split the original term into source words, normalize each
    # separately, and treat each word's Greek+Latin forms as alternatives.
    raw_words = String.split(String.trim(term), ~r/\s+/, trim: true)

    word_groups =
      Enum.map(raw_words, fn w ->
        String.split(Transliterate.normalize(w), " ", trim: true)
      end)

    biennales = search_group("biennale", ["field.theme", "field.statement"], word_groups, limit)

    events =
      search_group(
        "event",
        ["field.title", "field.location", "field.date", "field.description"],
        word_groups,
        limit
      )

    participants =
      search_group(
        "participant",
        ["field.name", "field.first_name", "field.last_name", "field.bio", "field.statement"],
        word_groups,
        limit
      )

    work_sections = [
      "field.title",
      "field.description",
      "field.statement",
      "identity",
      "field.synopsis",
      "field.log_line",
      "rel.creator",
      "rel.person",
      "rel.event"
    ]

    artworks = search_group(nil, work_sections, word_groups, limit, ["artwork"])

    films =
      search_group(nil, work_sections, word_groups, limit, [
        "Short Film",
        "Video",
        "Animation",
        "Documentary"
      ])

    performances = search_group(nil, work_sections, word_groups, limit, ["Dance"])

    total =
      length(biennales) + length(events) + length(participants) + length(artworks) + length(films) +
        length(performances)

    %{
      biennales: biennales,
      events: events,
      participants: participants,
      artworks: artworks,
      films: films,
      performances: performances,
      total: total
    }
  end

  defp work_types, do: ["artwork" | @film_types]

  defp search_group(type, sections, word_groups, limit, types \\ nil) do
    types = types || [type]

    pattern = build_regex_pattern(sections, word_groups)

    if pattern == "" do
      []
    else
      query =
        from e in Entity,
          where:
            e.visible == true and
              e.type in ^types and
              not is_nil(e.search_index) and
              fragment("? ~ ?", e.search_index, ^pattern),
          limit: ^limit,
          order_by: [asc: fragment("length(?)", e.search_index)]

      entities = Repo.all(query)

      Enum.map(entities, &entity_to_hit/1)
    end
  end

  defp build_regex_pattern(_sections, []), do: ""

  defp build_regex_pattern(sections, word_groups) do
    # word_groups is a list of lists: [["βενιερη", "venieri"], ["anna"]]
    # Each inner list is a group of alternatives (OR) for one source word.
    # All groups must match (AND via lookahead).
    #
    # For each group, build: (?:section1:[^:]*\mword1|section1:[^:]*\mword2|section2:[^:]*\mword1|...)
    # Then wrap in (?=.*(?:...)) for AND lookahead.

    word_patterns =
      Enum.map(word_groups, fn alternatives ->
        section_word_alts =
          for section <- sections, word <- alternatives do
            section_escaped = String.replace(section, ".", "\\.")
            "#{section_escaped}:[^:]*\\m#{escape_regex(word)}"
          end
          |> Enum.join("|")

        "(?=.*(?:#{section_word_alts}))"
      end)

    Enum.join(word_patterns)
  end

  defp escape_regex(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace(".", "\\.")
    |> String.replace("+", "\\+")
    |> String.replace("*", "\\*")
    |> String.replace("?", "\\?")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("|", "\\|")
    |> String.replace("^", "\\^")
    |> String.replace("$", "\\$")
    |> String.replace("/", "\\/")
  end

  # =====================================================================
  # Hit construction
  # =====================================================================

  defp entity_to_hit(%Entity{} = entity) do
    base = %{
      kind: :entity,
      id: entity.id,
      title: entity_title(entity),
      subtitle: entity_subtitle(entity),
      url: entity_url(entity),
      snippet: "",
      creators: [],
      events: []
    }

    case entity.type do
      t when t in ["artwork" | @film_types] ->
        %{
          base
          | creators: extract_rel_people(entity.search_index),
            events: extract_rel_events(entity.search_index)
        }

      "participant" ->
        %{
          base
          | creators: extract_participant_roles(entity.search_index),
            events: extract_participant_works(entity.search_index)
        }

      _ ->
        base
    end
  end

  @role_noise ~w(creator director editor producer screenwriter cinematographer composer actor actress lead lead_actor lead_actress exec exec_producer executive executive_producer production production_designer designer sound sound_editor sub_by writer photographer participated_in person creator curator)

  defp extract_rel_people(nil), do: []

  defp extract_rel_people(index) do
    ~r/(?:rel\.creator|rel\.person):([^:]+?)(?=\s+\w+\.|\s*$)/
    |> Regex.scan(index, capture: :all_but_first)
    |> List.flatten()
    |> Enum.flat_map(fn chunk ->
      chunk
      |> String.trim()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reject(&(&1 in @role_noise or String.match?(&1, ~r/^\p{L}{1,2}$/u)))
      |> case do
        [] -> []
        tokens -> [Enum.join(tokens, " ")]
      end
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp extract_rel_events(nil), do: []

  defp extract_rel_events(index) do
    ~r/rel\.event:([^:]+?)(?=\s+\w+\.|\s*$)/
    |> Regex.scan(index, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.match?(&1, ~r/^\d{4}-\d{2}-\d{2}$/)))
    |> Enum.uniq()
  end

  defp extract_participant_roles(nil), do: []

  defp extract_participant_roles(index) do
    # Extract roles from rel.in_artwork and rel.directed_film sections
    # The role appears as a token like "creator", "director" in these sections
    ~r/(?:rel\.in_artwork|rel\.directed_film|rel\.acted_in_film|rel\.participated_in_film):[^:]*?(\b(?:creator|director|curator|actor|actress|performer|editor|producer|writer|screenwriter|cinematographer|composer|participant)\b)/
    |> Regex.scan(index, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.map(&String.capitalize/1)
  end

  defp extract_participant_works(nil), do: []

  defp extract_participant_works(index) do
    ~r/(?:rel\.in_artwork|rel\.directed_film|rel\.acted_in_film|rel\.participated_in_film):([^:]+?)(?=\s+\w+\.|\s*$)/
    |> Regex.scan(index, capture: :all_but_first)
    |> List.flatten()
    |> Enum.flat_map(fn chunk ->
      chunk
      |> String.trim()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reject(fn token ->
        token in @role_noise or
          String.match?(token, ~r/^\d{4}(-\d{2}(-\d{2})?)?$/) or
          String.match?(token, ~r/^\d{4}-\d+$/) or
          String.match?(token, ~r/^\p{L}{1,2}$/u) or
          token in ~w(gr fr de us uk gb pk)
      end)
      |> case do
        [] -> []
        tokens -> [Enum.join(tokens, " ")]
      end
    end)
    |> Enum.reject(&(&1 == "" or String.match?(&1, ~r/^['"]?\d{2}['"]?$/)))
    |> Enum.uniq()
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

  defp entity_subtitle(%Entity{type: "biennale", fields: %{"theme" => theme}})
       when is_binary(theme),
       do: theme

  defp entity_subtitle(%Entity{type: "biennale"}), do: "Biennale Edition"

  defp entity_subtitle(%Entity{type: type, fields: fields}) do
    cond do
      type == "event" ->
        date = Map.get(fields, "date")
        location = Map.get(fields, "location")
        parts = [Map.get(fields, "type"), date, location] |> Enum.reject(&is_nil/1)
        if parts == [], do: "Event", else: Enum.join(parts, " · ")

      type == "participant" ->
        country = Map.get(fields, "country")
        if country, do: country, else: "Artist"

      type in work_types() ->
        type_label = humanize_type(type)
        date = Map.get(fields, "date")
        dir_by = Map.get(fields, "dir_by")
        base = if date, do: "#{type_label} · #{date}", else: type_label
        if dir_by && dir_by != "", do: "#{base} · Dir. #{dir_by}", else: base

      true ->
        humanize_type(type)
    end
  end

  defp humanize_type("Short Film"), do: "Short Film"
  defp humanize_type("Video"), do: "Video"
  defp humanize_type("Dance"), do: "Dance"
  defp humanize_type("Animation"), do: "Animation"
  defp humanize_type("Documentary"), do: "Documentary"
  defp humanize_type("artwork"), do: "Artwork"
  defp humanize_type("film"), do: "Film"
  defp humanize_type("event"), do: "Event"
  defp humanize_type("participant"), do: "Artist"
  defp humanize_type("biennale"), do: "Biennale"
  defp humanize_type(t) when is_binary(t), do: String.capitalize(t)
  defp humanize_type(_), do: ""

  defp entity_url(%Entity{type: "biennale", fields: %{"year" => y}}), do: "/archive/#{y}"
  defp entity_url(%Entity{type: "artwork"} = entity), do: "/art/#{entity.id}"
  defp entity_url(%Entity{type: "event"} = entity), do: "/event/#{entity.id}"
  defp entity_url(%Entity{type: "participant"} = entity), do: "/artist/#{entity.id}"
  defp entity_url(%Entity{type: type} = entity) when type in @film_types, do: "/art/#{entity.id}"
  defp entity_url(_), do: "/archive"

  # =====================================================================
  # Admin helper (unchanged)
  # =====================================================================

  @doc """
  Helper for admin LiveViews — returns a LIKE pattern for substring search.
  """
  def entity_search_pattern(term) when is_binary(term) and term != "" do
    "%" <> Transliterate.normalize(term) <> "%"
  end

  def entity_search_pattern(_), do: nil
end
