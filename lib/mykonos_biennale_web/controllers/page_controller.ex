defmodule MykonosBiennaleWeb.PageController do
  use MykonosBiennaleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
