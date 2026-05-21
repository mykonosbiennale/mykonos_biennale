defmodule MykonosBiennaleWeb.PageController do
  use MykonosBiennaleWeb, :controller
  alias MykonosBiennale.Content

  def home(conn, _params) do
    current_biennale_year =
      Application.get_env(:mykonos_biennale, :current_biennale_year, 2025)

    current_biennale = Content.get_biennale_by_year(current_biennale_year)

    events =
      if current_biennale do
        Content.list_events_for_biennale(current_biennale.fields["year"])
      else
        []
      end

    biennales = Content.list_biennales()

    biennale_media =
      biennales
      |> Enum.map(fn b -> {b.id, Content.list_media_for_entity(b)} end)
      |> Enum.into(%{})

    event_media =
      events
      |> Enum.map(fn e -> {e.id, Content.list_media_for_entity(e)} end)
      |> Enum.into(%{})

    conn
    |> assign(:page_title, page_title(current_biennale))
    |> assign(:biennale, current_biennale)
    |> assign(:events, events)
    |> assign(:biennales, biennales)
    |> assign(:biennale_media, biennale_media)
    |> assign(:event_media, event_media)
    |> render(:home)
  end

  defp page_title(nil), do: "Mykonos Biennale"
  defp page_title(biennale), do: "Mykonos Biennale #{biennale.fields["year"]}"
end
