defmodule MykonosBiennaleWeb.RobotsController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennaleWeb.Endpoint

  # The sitemap line uses the endpoint host, so it follows PHX_HOST on every deploy.
  def show(conn, _params) do
    body = """
    User-agent: *
    Allow: /

    Sitemap: #{Endpoint.url()}/sitemap.xml
    """

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end
end
