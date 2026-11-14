defmodule MykonosBiennaleWeb.AboutController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennaleWeb.Metadata

  def show(conn, _params) do
    render(conn, :show,
      page_title: "About",
      seo: Metadata.page(path: conn.request_path, title: "About")
    )
  end
end
