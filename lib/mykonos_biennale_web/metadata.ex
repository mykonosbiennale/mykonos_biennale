defmodule MykonosBiennaleWeb.Metadata do
  @moduledoc """
  SEO metadata for public pages.

  Controllers and LiveViews assign a map under `:seo` (see `page/1`). The root
  layout passes it to `head/1`, which renders the title, description, canonical
  link, robots, Open Graph, Twitter and JSON-LD tags through phoenix_seo.

  JSON-LD nodes are plain maps with schema.org `@type`s. Dates are only emitted
  when they are full ISO dates, so year-only values are left out.
  """

  use Phoenix.Component

  alias MykonosBiennaleWeb.Endpoint

  @site_name "Mykonos Biennale"
  @title_suffix " · Arts & Film Festival"
  @default_description "Mykonos Biennale is an arts and film festival on Mykonos, Greece, " <>
                         "bringing together artists, filmmakers and performers."
  @location "Mykonos, Greece"

  # --- Page assigns ---------------------------------------------------------

  @doc "Assigns for a page that should not be indexed."
  def noindex, do: %{robots: "noindex, nofollow"}

  @doc """
  Builds the `:seo` assign. `path` is the request path (for example `/biennale/2025`),
  which becomes the canonical URL.
  """
  def page(attrs) do
    %{
      title: attrs[:title],
      description: attrs[:description] |> plain_text() |> blank_to_nil(),
      canonical_url: attrs[:path] && Endpoint.url() <> attrs[:path],
      robots: attrs[:robots],
      jsonld: attrs[:jsonld]
    }
  end

  @doc "Metadata for a festival edition page (`/biennale/:slug`)."
  def for_biennale(biennale, path) do
    f = biennale.fields
    name = "#{@site_name} #{f["year"]}"

    page(
      path: path,
      description: f["description"] || f["statement"] || f["theme"],
      jsonld:
        compact(%{
          "@type" => "Event",
          "name" => name,
          "description" => plain_text(f["statement"] || f["description"]),
          "startDate" => iso_date(f["start_date"]),
          "endDate" => iso_date(f["end_date"]),
          "location" => place(@location),
          "organizer" => organization()
        })
    )
  end

  @doc "Metadata for an artwork page. `artist` is the artist's name or nil."
  def for_artwork(artwork, artist, path) do
    f = artwork.fields

    page(
      path: path,
      title: f["title"],
      description: f["description"],
      jsonld:
        compact(%{
          "@type" => "VisualArtwork",
          "name" => f["title"],
          "description" => plain_text(f["description"]),
          "artMedium" => f["medium"],
          "creator" => person(artist)
        })
    )
  end

  @doc "The year of an edition entity, or nil."
  def biennale_year(%{fields: %{"year" => year}}), do: year
  def biennale_year(_), do: nil

  @doc "Metadata for a film or video page. `director` is the director's name or nil."
  def for_film(film, director, biennale_year, path) do
    f = film.fields

    page(
      path: path,
      title: film.identity,
      description: f["synopsis"] || f["log_line"],
      jsonld:
        compact(%{
          "@type" => "Movie",
          "name" => film.identity,
          "description" => plain_text(f["synopsis"] || f["log_line"]),
          "director" => person(director),
          "dateCreated" => year_string(biennale_year),
          "isPartOf" => biennale_node(biennale_year)
        })
    )
  end

  @doc "Metadata for a participant page."
  def for_participant(name, participant, path) do
    page(
      path: path,
      title: name,
      description: participant.fields["bio"],
      jsonld:
        compact(%{
          "@type" => "Person",
          "name" => name,
          "description" => plain_text(participant.fields["bio"]),
          "nationality" => participant.fields["country"]
        })
    )
  end

  @doc "Metadata for an event page (`event` is the entity, `biennale_year` its edition's year)."
  def for_event(event, biennale_year, path) do
    f = event.fields

    page(
      path: path,
      title: f["title"],
      description: f["description"] || f["statement"],
      jsonld:
        compact(%{
          "@type" => "Event",
          "name" => f["title"],
          "description" => plain_text(f["description"] || f["statement"]),
          "additionalType" => f["type"],
          "startDate" => event_start(f["date"], f["time"]),
          "location" => place(f["location"]),
          "isPartOf" => biennale_node(biennale_year)
        })
    )
  end

  # --- Head ---------------------------------------------------------------

  @site_config %{title_suffix: @title_suffix, default_title: @site_name}
  @og_config %{site_name: @site_name}

  attr :seo, :map, default: %{}
  attr :page_title, :string, default: nil

  @doc "Renders the SEO head tags for the current page."
  def head(assigns) do
    seo = assigns.seo || %{}

    assigns =
      assigns
      |> assign(:site, site_item(seo))
      |> assign(:site_config, @site_config)
      |> assign(:og, og_item(seo))
      |> assign(:og_config, @og_config)
      |> assign(:twitter, twitter_item(seo))
      |> assign(:jsonld, seo[:jsonld])

    ~H"""
    <SEO.Site.meta item={@site} page_title={@page_title} config={@site_config} />
    <SEO.OpenGraph.meta item={@og} config={@og_config} />
    <SEO.Twitter.meta item={@twitter} />
    <SEO.JSONLD.meta :if={@jsonld} item={@jsonld} json_library={Jason} />
    """
  end

  defp site_item(seo) do
    SEO.Site.build(
      %{
        title: seo[:title],
        description: seo[:description] || @default_description,
        canonical_url: seo[:canonical_url],
        robots: seo[:robots]
      },
      @site_config
    )
  end

  defp og_item(seo) do
    SEO.OpenGraph.build(%{
      title: seo[:title] || @site_name,
      description: seo[:description] || @default_description,
      url: seo[:canonical_url]
    })
  end

  defp twitter_item(seo) do
    SEO.Twitter.build(%{
      title: seo[:title] || @site_name,
      description: seo[:description] || @default_description
    })
  end

  # --- JSON-LD helpers ----------------------------------------------------

  defp organization do
    %{"@type" => "Organization", "name" => @site_name}
  end

  defp place(nil), do: nil
  defp place(""), do: nil
  defp place(name), do: %{"@type" => "Place", "name" => name}

  defp person(nil), do: nil
  defp person(""), do: nil
  defp person(name), do: %{"@type" => "Person", "name" => name}

  defp biennale_node(year) when year in [nil, ""], do: nil

  defp biennale_node(year) do
    %{"@type" => "Event", "name" => "#{@site_name} #{year}"}
  end

  defp year_string(nil), do: nil
  defp year_string(year), do: to_string(year)

  defp event_start(date, time) do
    with day when is_binary(day) <- iso_date(date) do
      case clock_time(time) do
        nil -> day
        clock -> "#{day}T#{clock}"
      end
    end
  end

  defp clock_time(time) when is_binary(time) do
    case Regex.run(~r/^(\d{1,2}):(\d{2})$/, String.trim(time)) do
      [_, h, m] -> "#{pad(h)}:#{m}"
      _ -> nil
    end
  end

  defp clock_time(_), do: nil

  defp pad(value), do: String.pad_leading(value, 2, "0")

  @doc "Returns `YYYY-MM-DD` for a full ISO date string, otherwise nil."
  def iso_date(value) when is_binary(value) do
    value = String.trim(value)

    case Date.from_iso8601(value) do
      {:ok, date} -> Date.to_iso8601(date)
      _ -> nil
    end
  end

  def iso_date(_), do: nil

  @doc "Strips HTML tags and collapses whitespace. Returns nil for empty input."
  def plain_text(nil), do: nil

  def plain_text(html) when is_binary(html) do
    html
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> blank_to_nil()
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp compact(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" end)
    |> Map.new()
  end
end
