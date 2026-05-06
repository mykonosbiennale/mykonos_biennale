defmodule MykonosBiennaleWeb.Admin.DashboardLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    biennales = Content.list_biennales()
    all_events = Content.list_events()
    participants = Content.list_participants()
    artworks = Content.list_artworks()

    total_biennales = length(biennales)
    total_events = length(all_events)
    total_participants = length(participants)
    total_artworks = length(artworks)
    total_media = length(Content.list_media())

    recent_biennales = Enum.take(biennales, 3)

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:total_biennales, total_biennales)
     |> assign(:total_events, total_events)
     |> assign(:total_participants, total_participants)
     |> assign(:total_artworks, total_artworks)
     |> assign(:total_media, total_media)
     |> assign(:recent_biennales, recent_biennales)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-screen bg-gradient-to-br from-gray-900 via-purple-900 to-gray-900">
        <.admin_nav current_page="dashboard" />

        <%!-- Main Content --%>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <%!-- Stats Grid --%>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-12">
            <%!-- Total Biennales --%>
            <div class="bg-gradient-to-br from-purple-900/20 to-purple-950/20 border border-purple-800/30 rounded-lg p-6 hover:border-purple-700/50 transition-colors">
              <div class="flex items-center justify-between mb-4">
                <.icon name="hero-calendar" class="size-8 text-purple-400" />
                <span class="text-3xl font-bold text-white">{@total_biennales}</span>
              </div>
              <h3 class="text-sm uppercase tracking-wider text-gray-400">Total Biennales</h3>
            </div>

            <%!-- Total Events --%>
            <div class="bg-gradient-to-br from-blue-900/20 to-blue-950/20 border border-blue-800/30 rounded-lg p-6 hover:border-blue-700/50 transition-colors">
              <div class="flex items-center justify-between mb-4">
                <.icon name="hero-star" class="size-8 text-blue-400" />
                <span class="text-3xl font-bold text-white">{@total_events}</span>
              </div>
              <h3 class="text-sm uppercase tracking-wider text-gray-400">Total Events</h3>
            </div>

            <%!-- Participants --%>
            <div class="bg-gradient-to-br from-green-900/20 to-green-950/20 border border-green-800/30 rounded-lg p-6 hover:border-green-700/50 transition-colors">
              <div class="flex items-center justify-between mb-4">
                <.icon name="hero-user-group" class="size-8 text-green-400" />
                <span class="text-3xl font-bold text-white">{@total_participants}</span>
              </div>
              <h3 class="text-sm uppercase tracking-wider text-gray-400">Participants</h3>
            </div>

            <%!-- Works Shown --%>
            <div class="bg-gradient-to-br from-red-900/20 to-red-950/20 border border-red-800/30 rounded-lg p-6 hover:border-red-700/50 transition-colors">
              <div class="flex items-center justify-between mb-4">
                <.icon name="hero-paint-brush" class="size-8 text-red-400" />
                <span class="text-3xl font-bold text-white">{@total_artworks}</span>
              </div>
              <h3 class="text-sm uppercase tracking-wider text-gray-400">Works Shown</h3>
            </div>

            <%!-- Media --%>
            <div class="bg-gradient-to-br from-amber-900/20 to-amber-950/20 border border-amber-800/30 rounded-lg p-6 hover:border-amber-700/50 transition-colors">
              <div class="flex items-center justify-between mb-4">
                <.icon name="hero-photo" class="size-8 text-amber-400" />
                <span class="text-3xl font-bold text-white">{@total_media}</span>
              </div>
              <h3 class="text-sm uppercase tracking-wider text-gray-400">Media</h3>
            </div>
          </div>

          <%!-- Quick Actions --%>
          <div class="mb-12">
            <h2 class="text-xl font-bold uppercase mb-6 text-gray-300">Quick Actions</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.link
                navigate={~p"/admin/biennales/new"}
                class="flex items-center gap-4 p-6 bg-gradient-to-r from-purple-900/30 to-purple-800/20 border border-purple-700/30 rounded-lg hover:border-purple-600/50 transition-all group"
              >
                <div class="p-3 bg-purple-500/20 rounded-lg group-hover:bg-purple-500/30 transition-colors">
                  <.icon name="hero-plus" class="size-6 text-purple-400" />
                </div>
                <div>
                  <h3 class="font-bold text-white uppercase tracking-wider">New Biennale</h3>
                  <p class="text-sm text-gray-400">Create a new biennale edition</p>
                </div>
              </.link>

              <.link
                navigate={~p"/admin/events/new"}
                class="flex items-center gap-4 p-6 bg-gradient-to-r from-blue-900/30 to-blue-800/20 border border-blue-700/30 rounded-lg hover:border-blue-600/50 transition-all group"
              >
                <div class="p-3 bg-blue-500/20 rounded-lg group-hover:bg-blue-500/30 transition-colors">
                  <.icon name="hero-plus" class="size-6 text-blue-400" />
                </div>
                <div>
                  <h3 class="font-bold text-white uppercase tracking-wider">New Event</h3>
                  <p class="text-sm text-gray-400">Add an event to a biennale</p>
                </div>
              </.link>
            </div>
          </div>

          <%!-- Recent Biennales --%>
          <div>
            <div class="flex items-center justify-between mb-6">
              <h2 class="text-xl font-bold uppercase text-gray-300">Recent Biennales</h2>
              <.link
                navigate={~p"/admin/biennales"}
                class="text-sm text-gray-400 hover:text-white uppercase tracking-wider transition-colors"
              >
                View All →
              </.link>
            </div>

            <%= if @recent_biennales == [] do %>
              <div class="text-center py-12 border border-gray-800 rounded-lg">
                <p class="text-gray-500 mb-4">No biennales created yet.</p>
                <.link
                  navigate={~p"/admin/biennales/new"}
                  class="inline-block px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-bold uppercase tracking-wider rounded-lg transition-colors"
                >
                  Create First Biennale
                </.link>
              </div>
            <% else %>
              <div class="space-y-4">
                <%= for biennale <- @recent_biennales do %>
                  <.link
                    navigate={~p"/admin/biennales/#{biennale.id}"}
                    class="block p-6 bg-gray-900/50 border border-gray-800 rounded-lg hover:border-gray-700 transition-all group"
                  >
                    <div class="flex items-center justify-between">
                      <div>
                        <h3 class="text-lg font-bold text-white group-hover:text-purple-400 transition-colors">
                          {biennale.fields["year"]} - {biennale.fields["theme"]}
                        </h3>
                        <%= if biennale.fields["start_date"] && biennale.fields["end_date"] do %>
                          <p class="text-sm text-gray-500 mt-1">
                            {format_date(biennale.fields["start_date"], "%B %d")} – {format_date(
                              biennale.fields["end_date"],
                              "%B %d, %Y"
                            )}
                          </p>
                        <% end %>
                      </div>
                      <.icon
                        name="hero-chevron-right"
                        class="size-5 text-gray-600 group-hover:text-purple-400 transition-colors"
                      />
                    </div>
                  </.link>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_date(%Date{} = date, fmt), do: Calendar.strftime(date, fmt)

  defp format_date(date_string, fmt) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, fmt)
      _ -> date_string
    end
  end

  defp format_date(_, _), do: ""
end
