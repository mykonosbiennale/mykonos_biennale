defmodule MykonosBiennaleWeb.Discovery do
  @moduledoc """
  The public pages of the site, read from the database. Used by the sitemap and
  llms.txt so both list the same pages.
  """

  import Ecto.Query, warn: false

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Repo
  alias MykonosBiennale.SEO
  alias MykonosBiennaleWeb.Endpoint
  alias MykonosBiennaleWeb.Metadata

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]
  @entity_types ["biennale", "event", "artwork", "participant"] ++ @film_types

  @static_pages [
    %{path: "/", title: "Mykonos Biennale", description: nil, section: :pages},
    %{path: "/archive", title: "Archive", description: "All editions", section: :pages},
    %{path: "/program", title: "Program", description: "Current program", section: :pages},
    %{path: "/about", title: "About", description: "About the festival", section: :pages}
  ]

  @doc "Static pages plus every visible entity, each as a map with path, title, description, section and updated_at."
  def entries do
    static = Enum.map(@static_pages, &Map.put(&1, :updated_at, nil))
    static ++ Enum.map(visible_entities(), &entry/1)
  end

  @doc "The absolute URL for a path."
  def url(path), do: Endpoint.url() <> path

  defp visible_entities do
    Repo.all(
      from e in Entity,
        where: e.visible == true and e.type in ^@entity_types,
        order_by: [e.type, e.id],
        select: %{
          id: e.id,
          type: e.type,
          slug: e.slug,
          identity: e.identity,
          fields: e.fields,
          seo: e.seo,
          updated_at: e.updated_at
        }
    )
  end

  defp entry(%{type: "biennale"} = e) do
    year = e.fields["year"]
    seo = SEO.overrides(e)

    %{
      path: "/biennale/#{e.slug}",
      title: seo["title"] || "Mykonos Biennale #{year}",
      description: text(seo["description"] || SEO.defaults(e).description),
      section: :editions,
      updated_at: e.updated_at
    }
  end

  defp entry(%{type: "event"} = e), do: entity_entry(e, "/event/#{e.id}", :events)
  defp entry(%{type: "artwork"} = e), do: entity_entry(e, "/art/#{e.id}", :artworks)
  defp entry(%{type: "participant"} = e), do: entity_entry(e, "/artist/#{e.id}", :artists)

  defp entry(%{type: _film} = e), do: entity_entry(e, "/film/#{e.id}", :films)

  defp entity_entry(e, path, section) do
    seo = SEO.overrides(e)
    defaults = SEO.defaults(e)

    %{
      path: path,
      title: seo["title"] || defaults.title || e.identity || "Untitled",
      description: text(seo["description"] || defaults.description),
      section: section,
      updated_at: e.updated_at
    }
  end

  defp text(value) do
    case Metadata.plain_text(value) do
      nil ->
        nil

      plain ->
        if String.length(plain) > 160, do: String.slice(plain, 0, 157) <> "...", else: plain
    end
  end
end
