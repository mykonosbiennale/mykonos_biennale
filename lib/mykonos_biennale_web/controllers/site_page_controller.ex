defmodule MykonosBiennaleWeb.SitePageController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Site
  alias MykonosBiennaleWeb.SitePageHTML

  def show(conn, %{"slug" => slug}) do
    case Site.get_page_by_slug(slug) do
      nil ->
        not_found(conn)

      %{visible: false} ->
        not_found(conn)

      page ->
        assigns = %{
          page: page,
          page_title: page.title
        }

        page_content =
          SitePageHTML.render_content(page.content, assigns)

        conn
        |> assign(:page, page)
        |> assign(:page_content, page_content)
        |> assign(:page_title, page.title)
        |> render_template(page)
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end

  defp render_template(conn, %{template: :none}) do
    render(conn, :none)
  end

  defp render_template(conn, _page) do
    render(conn, :page)
  end
end
