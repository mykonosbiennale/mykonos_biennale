defmodule MykonosBiennaleWeb.ProgramLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    # Get the current/most recent biennale (2025)
    current_biennale = Content.get_biennale_by_year(2025)

    if current_biennale do
      events = Content.list_events_for_biennale(current_biennale.fields["year"])

      {:ok,
       socket
       |> assign(:page_title, "Program #{current_biennale.fields["year"]}")
       |> assign(:biennale, current_biennale)
       |> assign(:events, events)
       |> assign(:events_by_type, group_events_by_type(events))}
    else
      {:ok,
       socket
       |> put_flash(:error, "No current biennale found")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  defp group_events_by_type(events) do
    Enum.group_by(events, & &1.fields["type"])
  end

  defp event_type_title(type) do
    case type do
      "exhibition" -> "Exhibitions"
      "performance" -> "Performances"
      "screening" -> "Screenings"
      "short_films" -> "Short Films"
      "workshop" -> "Workshops"
      "celebration" -> "Celebrations"
      _ -> String.capitalize(type)
    end
  end

  defp event_type_description(type) do
    case type do
      "exhibition" ->
        "Contemporary art installations across multiple venues in Mykonos, featuring international and local artists."

      "performance" ->
        "Live performances, experimental theater, and site-specific interventions exploring contemporary themes."

      "screening" ->
        "Film screenings, video projections, and dramatic nights showcasing cutting-edge cinema and visual storytelling."

      "short_films" ->
        "International experimental and narrative short film screenings showcasing cutting-edge cinema."

      "workshop" ->
        "Artist-led workshops and masterclasses exploring contemporary art practices and techniques."

      "celebration" ->
        "Festive events and celebrations part of the Mykonos Biennale."

      _ ->
        ""
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
              navigate={~p"/"}
              class="text-sm text-gray-400 hover:text-white uppercase tracking-wider mb-8 inline-block"
            >
              ← Back to Home
            </.link>

            <div class="space-y-4">
              <h1 class="text-5xl md:text-7xl lg:text-8xl font-bold uppercase tracking-tight">
                Program {@biennale.fields["year"]}
              </h1>

              <p class="text-2xl md:text-3xl text-gray-400 font-light">
                {@biennale.fields["theme"]}
              </p>

              <%= if @biennale.fields["start_date"] && @biennale.fields["end_date"] do %>
                <p class="text-lg text-gray-500 uppercase tracking-wider">
                  {Calendar.strftime(Date.from_iso8601!(@biennale.fields["start_date"]), "%B %d")} – {Calendar.strftime(
                    Date.from_iso8601!(@biennale.fields["end_date"]),
                    "%B %d, %Y"
                  )}
                </p>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Events by Type --%>
        <%= if @events == [] do %>
          <div class="px-6 py-20 md:py-32">
            <div class="max-w-4xl mx-auto text-center">
              <p class="text-2xl text-gray-500">
                The program for {@biennale.fields["year"]} will be announced soon.
              </p>
              <p class="text-lg text-gray-600 mt-4">
                Check back later for the full schedule of events.
              </p>
            </div>
          </div>
        <% else %>
          <div class="px-6 py-16 md:py-24">
            <div class="max-w-7xl mx-auto space-y-20">
              <%= for type <- ["exhibition", "performance", "screening", "short_films", "workshop", "celebration", "event", "festival"] do %>
                <%= if Map.has_key?(@events_by_type, type) do %>
                  <div class="space-y-8">
                    <%!-- Type Header --%>
                    <div class="border-b border-gray-800 pb-6">
                      <h2 class="text-3xl md:text-5xl font-bold uppercase mb-3">
                        {event_type_title(type)}
                      </h2>
                      <p class="text-gray-400 text-lg max-w-3xl">
                        {event_type_description(type)}
                      </p>
                    </div>

                    <%!-- Events Grid --%>
                    <div class="grid md:grid-cols-2 gap-8">
                      <%= for event <- @events_by_type[type] do %>
                        <div class="bg-gray-900/50 border border-gray-800 p-6 hover:border-gray-700 transition-all">
                          <h3 class="text-2xl font-bold mb-3">
                            <.link navigate={~p"/event/#{event.id}"} class="hover:text-gray-300 transition-colors">
                              {event.fields["title"]}
                            </.link>
                          </h3>

                          <div class="space-y-2 mb-4">
                            <%= if event.fields["date"] do %>
                              <p class="text-sm text-gray-400 uppercase tracking-wider">
                                <span class="text-gray-600">Date:</span>
                                {Calendar.strftime(
                                  Date.from_iso8601!(event.fields["date"]),
                                  "%A, %B %d, %Y"
                                )}
                              </p>
                            <% end %>

                            <%= if event.fields["location"] do %>
                              <p class="text-sm text-gray-400">
                                <span class="text-gray-600">Location:</span> {event.fields["location"]}
                              </p>
                            <% end %>
                          </div>

                          <%= if event.fields["description"] do %>
                            <p class="text-gray-300 leading-relaxed">
                              {event.fields["description"]}
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
        <% end %>

        <%!-- Footer --%>
        <div class="px-6 py-12 border-t border-gray-800">
          <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="text-center md:text-left">
              <p class="text-sm text-gray-400 uppercase tracking-wider">
                Mykonos Biennale © {@biennale.fields["year"]}
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
              <.link
                navigate={~p"/about"}
                class="text-sm text-gray-400 hover:text-white uppercase tracking-wider"
              >
                About
              </.link>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
