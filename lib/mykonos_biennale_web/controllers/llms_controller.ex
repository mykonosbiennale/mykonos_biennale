defmodule MykonosBiennaleWeb.LlmsController do
  @moduledoc """
  Serves /llms.txt, a plain-text summary of the site for language models
  (see https://llmstxt.org). Lists the same pages as the sitemap.
  """

  use MykonosBiennaleWeb, :controller

  alias MykonosBiennaleWeb.Discovery
  alias MykonosBiennaleWeb.DiscoveryCache

  @sections [
    {:pages, "Pages"},
    {:editions, "Editions"},
    {:events, "Events"},
    {:films, "Films and videos"},
    {:artworks, "Artworks"},
    {:artists, "Artists"}
  ]

  def show(conn, _params) do
    body = DiscoveryCache.fetch(:llms, &build/0)

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end

  defp build do
    entries = Discovery.entries()

    [
      "# Mykonos Biennale\n",
      "\n> Mykonos Biennale is an international contemporary arts and film festival on Mykonos, Greece.\n",
      Enum.map_join(@sections, fn {section, heading} ->
        lines =
          entries
          |> Enum.filter(&(&1.section == section))
          |> Enum.map_join(fn entry -> line(entry) end)

        if lines == "", do: "", else: "\n## #{heading}\n\n" <> lines
      end)
    ]
    |> IO.iodata_to_binary()
  end

  defp line(entry) do
    description = if entry.description, do: ": #{entry.description}", else: ""
    "- [#{entry.title}](#{Discovery.url(entry.path)})#{description}\n"
  end
end
