defmodule MykonosBiennaleWeb.BiennaleController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Content
  alias MykonosBiennaleWeb.BiennaleHTML

  def show(conn, %{"slug" => slug}) do
    case Content.get_entity_by_slug(slug) do
      %{type: "biennale", visible: true} = biennale ->
        conn
        |> assign(:biennale, biennale)
        |> assign(:events, load_events(biennale))
        |> assign(:biennale_media, Content.list_media_for_entity(biennale))
        |> assign(
          :page_title,
          "#{biennale.fields["theme"]} — Mykonos Biennale #{biennale.fields["year"]}"
        )
        |> render_template(biennale)

      %{visible: false} ->
        not_found(conn)

      nil ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  defp load_events(biennale) do
    year = parse_year(biennale.fields["year"])
    Content.list_events_for_biennale(year) |> Enum.map(&present_event/1)
  end

  defp render_template(conn, %{template: :none}) do
    biennale = conn.assigns.biennale
    content = BiennaleHTML.render_content(biennale.fields["content"], conn.assigns)

    conn
    |> assign(:page_content, content)
    |> render(:none)
  end

  defp render_template(conn, "list") do
    render(conn, :list)
  end

  defp render_template(conn, _template) do
    render(conn, :biennale)
  end

  defp present_event(%MykonosBiennale.Content.Entity{} = entity) do
    media = Content.list_media_for_entity(entity)

    background =
      case List.last(media) do
        %{source_type: "upload", source_path: path} when is_binary(path) ->
          "/uploads/#{path}"

        %{source_type: "url", source_url: url} when is_binary(url) ->
          url

        _ ->
          nil
      end

    %{
      id: entity.id,
      title: entity.fields["title"],
      type: entity.fields["type"],
      date: entity.fields["date"],
      description: entity.fields["description"],
      slug: entity.slug,
      background_image: background
    }
  end

  defp parse_year(nil), do: nil
  defp parse_year(y) when is_integer(y), do: y

  defp parse_year(y) when is_binary(y) do
    case Integer.parse(y) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
