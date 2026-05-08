defmodule MykonosBiennaleWeb.ArchiveDetailLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content

  @impl true
  def mount(%{"year" => year_str}, _session, socket) do
    year = String.to_integer(year_str)

    case Content.get_biennale_by_year(year) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Biennale #{year} not found")
         |> redirect(to: ~p"/archive")}

      biennale_entity ->
        biennale = present_biennale(biennale_entity)
        events = year |> Content.list_events_for_biennale() |> Enum.map(&present_event/1)

        {:ok,
         socket
         |> assign(:page_title, "#{biennale.year} - #{biennale.theme}")
         |> assign(:biennale, biennale)
         |> assign(:events, events)
         |> assign(:events_by_type, group_events_by_type(events))}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp present_biennale(%MykonosBiennale.Content.Entity{fields: fields}) do
    %{
      year: parse_year(fields["year"]),
      theme: fields["theme"],
      statement: fields["statement"],
      description: fields["description"],
      start_date: parse_date(fields["start_date"]),
      end_date: parse_date(fields["end_date"])
    }
  end

  defp present_event(%MykonosBiennale.Content.Entity{fields: fields}) do
    %{
      title: fields["title"],
      type: fields["type"] || "other",
      date: parse_date(fields["date"]),
      location: fields["location"],
      description: fields["description"]
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

  defp parse_date(nil), do: nil
  defp parse_date(%Date{} = d), do: d
  defp parse_date(s) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  defp group_events_by_type(events) do
    Enum.group_by(events, & &1.type)
  end

  defp event_type_title(type) do
    case type do
      "exhibition" -> "Exhibitions"
      "performance" -> "Performances"
      "video_graffiti" -> "Video Graffiti"
      "dramatic_nights" -> "Dramatic Nights"
      "short_films" -> "Short Films"
      "workshop" -> "Workshops"
      _ -> String.capitalize(type)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-black text-white">
        <%!-- Header --%>
        <div class="px-6 py-12 md:py-20 border-b border-gray-800">
          <div class="max-w-7xl mx-auto">
            <.link
              navigate={~p"/archive"}
              class="text-sm text-gray-400 hover:text-white uppercase tracking-wider mb-8 inline-block"
            >
              ← Back to Archive
            </.link>

            <div class="space-y-4">
              <h1 class="text-5xl md:text-7xl lg:text-8xl font-bold uppercase tracking-tight">
                {@biennale.theme}
              </h1>

              <p class="text-3xl md:text-4xl text-gray-400 font-light">
                {@biennale.year}
              </p>

              <%= if @biennale.start_date && @biennale.end_date do %>
                <p class="text-lg text-gray-500 uppercase tracking-wider">
                  {Calendar.strftime(@biennale.start_date, "%B %d")} – {Calendar.strftime(
                    @biennale.end_date,
                    "%B %d, %Y"
                  )}
                </p>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Statement Section --%>
        <%= if @biennale.statement do %>
          <div class="px-6 py-16 md:py-24 bg-gray-950">
            <div class="max-w-4xl mx-auto">
              <h2 class="text-2xl md:text-3xl font-bold uppercase mb-8 text-gray-400">
                Statement
              </h2>
              <p class="text-lg md:text-xl leading-relaxed text-gray-300">
                {@biennale.statement}
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Description Section --%>
        <%= if @biennale.description do %>
          <div class="px-6 py-16 md:py-24">
            <div class="max-w-4xl mx-auto">
              <p class="text-base md:text-lg leading-relaxed text-gray-400">
                {@biennale.description}
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Program Section --%>
        <%= if @events != [] do %>
          <div class="px-6 py-16 md:py-24 bg-gray-950">
            <div class="max-w-7xl mx-auto">
              <h2 class="text-3xl md:text-5xl font-bold uppercase mb-12">
                Program
              </h2>

              <div class="space-y-16">
                <%= for type <- ["exhibition", "performance", "video_graffiti", "dramatic_nights", "short_films", "workshop"] do %>
                  <%= if Map.has_key?(@events_by_type, type) do %>
                    <div class="border-l-4 border-gray-700 pl-6 md:pl-8">
                      <h3 class="text-2xl md:text-3xl font-bold uppercase mb-6 text-gray-300">
                        {event_type_title(type)}
                      </h3>

                      <div class="space-y-6">
                        <%= for event <- @events_by_type[type] do %>
                          <div class="border-b border-gray-800 pb-6 last:border-b-0 last:pb-0">
                            <h4 class="text-xl font-bold mb-2">
                              {event.title}
                            </h4>

                            <%= if event.date do %>
                              <p class="text-sm text-gray-500 uppercase tracking-wider mb-2">
                                {Calendar.strftime(event.date, "%B %d, %Y")}
                              </p>
                            <% end %>

                            <%= if event.location do %>
                              <p class="text-sm text-gray-400 mb-3">
                                <span class="text-gray-600">Location:</span> {event.location}
                              </p>
                            <% end %>

                            <%= if event.description do %>
                              <p class="text-gray-400 leading-relaxed">
                                {event.description}
                              </p>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>
        <% else %>
          <div class="px-6 py-16 md:py-24">
            <div class="max-w-4xl mx-auto text-center">
              <p class="text-xl text-gray-500">
                No events have been added to this biennale yet.
              </p>
            </div>
          </div>
        <% end %>

        <%!-- Footer --%>
        <div class="px-6 py-12 border-t border-gray-800">
          <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="text-center md:text-left">
              <p class="text-sm text-gray-400 uppercase tracking-wider">
                Mykonos Biennale © {@biennale.year}
              </p>
            </div>

            <div class="flex gap-6">
              <.link
                navigate={~p"/"}
                class="text-sm text-gray-400 hover:text-white uppercase tracking-wider"
              >
                Home
              </.link>
              <.link
                navigate={~p"/archive"}
                class="text-sm text-gray-400 hover:text-white uppercase tracking-wider"
              >
                Archive
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
