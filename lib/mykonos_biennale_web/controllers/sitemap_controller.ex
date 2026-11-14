defmodule MykonosBiennaleWeb.SitemapController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennaleWeb.Discovery
  alias MykonosBiennaleWeb.DiscoveryCache

  defp build do
    ~s(<?xml version="1.0" encoding="UTF-8"?>\n) <>
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n) <>
      Enum.map_join(Discovery.entries(), &url_entry/1) <>
      "</urlset>\n"
  end

  def show(conn, _params) do
    xml = DiscoveryCache.fetch(:sitemap, &build/0)

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, xml)
  end

  defp url_entry(entry) do
    lastmod =
      case entry.updated_at do
        %DateTime{} = at ->
          "\n    <lastmod>#{at |> DateTime.to_date() |> Date.to_iso8601()}</lastmod>"

        _ ->
          ""
      end

    "  <url>\n    <loc>#{escape(Discovery.url(entry.path))}</loc>#{lastmod}\n  </url>\n"
  end

  defp escape(value), do: value |> Plug.HTML.html_escape() |> IO.iodata_to_binary()
end
