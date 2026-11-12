defmodule MykonosBiennaleWeb.ArchiveController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Content

  def index(conn, _params) do
    render(conn, :index,
      page_title: "Archive",
      biennales: Content.list_biennales()
    )
  end
end
