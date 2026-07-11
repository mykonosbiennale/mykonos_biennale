defmodule MykonosBiennaleWeb.Admin.DashboardLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content
  alias MykonosBiennale.Thumbnail

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @impl true
  def mount(_params, _session, socket) do
    import Ecto.Query, warn: false
    alias MykonosBiennale.Repo
    alias MykonosBiennale.Content.Entity

    biennales = Content.list_biennales()
    all_events = Content.list_events()
    participants = Content.list_participants()
    artworks = Content.list_artworks()
    total_media = length(Content.list_media())

    total_films =
      Repo.one(from e in Entity, where: e.type in ^@film_types, select: count(e.id))

    current_biennale = List.first(biennales)
    cache_stats = Thumbnail.cache_stats()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:total_biennales, length(biennales))
     |> assign(:total_events, length(all_events))
     |> assign(:total_participants, length(participants))
     |> assign(:total_artworks, length(artworks))
     |> assign(:total_films, total_films)
     |> assign(:total_media, total_media)
     |> assign(:current_biennale, current_biennale)
     |> assign(:cache_files, cache_stats.files)
     |> assign(:cache_size, format_bytes(cache_stats.bytes))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_thumbnail_cache", _params, socket) do
    count = Thumbnail.clear_all_cache()
    legacy_count = Thumbnail.clear_legacy_cache()
    cache_stats = Thumbnail.cache_stats()

    {:noreply,
     socket
     |> assign(:cache_files, cache_stats.files)
     |> assign(:cache_size, format_bytes(cache_stats.bytes))
     |> put_flash(
       :info,
       "Cleared #{count + legacy_count} cached thumbnail(s). They will regenerate on next access."
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-6 gap-6 mb-12">
          <div class="bg-gradient-to-br from-purple-900/20 to-purple-950/20 border border-purple-800/30 rounded-lg p-6 hover:border-purple-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-calendar" class="size-8 text-purple-400" />
              <span class="text-3xl font-bold text-white">{@total_biennales}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Biennales</h3>
          </div>

          <div class="bg-gradient-to-br from-blue-900/20 to-blue-950/20 border border-blue-800/30 rounded-lg p-6 hover:border-blue-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-star" class="size-8 text-blue-400" />
              <span class="text-3xl font-bold text-white">{@total_events}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Events</h3>
          </div>

          <div class="bg-gradient-to-br from-green-900/20 to-green-950/20 border border-green-800/30 rounded-lg p-6 hover:border-green-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-user-group" class="size-8 text-green-400" />
              <span class="text-3xl font-bold text-white">{@total_participants}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Participants</h3>
          </div>

          <div class="bg-gradient-to-br from-red-900/20 to-red-950/20 border border-red-800/30 rounded-lg p-6 hover:border-red-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-paint-brush" class="size-8 text-red-400" />
              <span class="text-3xl font-bold text-white">{@total_artworks}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Artworks</h3>
          </div>

          <div class="bg-gradient-to-br from-cyan-900/20 to-cyan-950/20 border border-cyan-800/30 rounded-lg p-6 hover:border-cyan-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-film" class="size-8 text-cyan-400" />
              <span class="text-3xl font-bold text-white">{@total_films}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Films / Videos</h3>
          </div>

          <div class="bg-gradient-to-br from-amber-900/20 to-amber-950/20 border border-amber-800/30 rounded-lg p-6 hover:border-amber-700/50 transition-colors">
            <div class="flex items-center justify-between mb-4">
              <.icon name="hero-photo" class="size-8 text-amber-400" />
              <span class="text-3xl font-bold text-white">{@total_media}</span>
            </div>
            <h3 class="text-sm uppercase tracking-wider text-gray-400">Media</h3>
          </div>
        </div>

        <div class="mb-12">
          <h2 class="text-xl font-bold uppercase mb-6 text-gray-300">Quick Actions</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
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

            <.link
              navigate={~p"/admin/participants/new"}
              class="flex items-center gap-4 p-6 bg-gradient-to-r from-green-900/30 to-green-800/20 border border-green-700/30 rounded-lg hover:border-green-600/50 transition-all group"
            >
              <div class="p-3 bg-green-500/20 rounded-lg group-hover:bg-green-500/30 transition-colors">
                <.icon name="hero-plus" class="size-6 text-green-400" />
              </div>
              <div>
                <h3 class="font-bold text-white uppercase tracking-wider">New Participant</h3>
                <p class="text-sm text-gray-400">Add an artist or participant</p>
              </div>
            </.link>

            <.link
              navigate={~p"/admin/artworks/new"}
              class="flex items-center gap-4 p-6 bg-gradient-to-r from-red-900/30 to-red-800/20 border border-red-700/30 rounded-lg hover:border-red-600/50 transition-all group"
            >
              <div class="p-3 bg-red-500/20 rounded-lg group-hover:bg-red-500/30 transition-colors">
                <.icon name="hero-plus" class="size-6 text-red-400" />
              </div>
              <div>
                <h3 class="font-bold text-white uppercase tracking-wider">New Artwork</h3>
                <p class="text-sm text-gray-400">Add an artwork to the archive</p>
              </div>
            </.link>

            <.link
              patch={~p"/admin/films/new"}
              class="flex items-center gap-4 p-6 bg-gradient-to-r from-cyan-900/30 to-cyan-800/20 border border-cyan-700/30 rounded-lg hover:border-cyan-600/50 transition-all group"
            >
              <div class="p-3 bg-cyan-500/20 rounded-lg group-hover:bg-cyan-500/30 transition-colors">
                <.icon name="hero-plus" class="size-6 text-cyan-400" />
              </div>
              <div>
                <h3 class="font-bold text-white uppercase tracking-wider">New Film</h3>
                <p class="text-sm text-gray-400">Add a film or video entry</p>
              </div>
            </.link>
          </div>
        </div>

        <div class="mb-12">
          <h2 class="text-xl font-bold uppercase mb-6 text-gray-300">Media Management</h2>
          <div class="bg-gray-900/50 border border-gray-800 rounded-lg p-6">
            <div class="flex items-center justify-between flex-wrap gap-4">
              <div>
                <h3 class="font-bold text-white uppercase tracking-wider mb-1">Thumbnail Cache</h3>
                <p class="text-sm text-gray-400">
                  {@cache_files} files · {@cache_size}
                </p>
                <p class="text-xs text-gray-500 mt-2">
                  Clearing the cache forces all thumbnails to regenerate on next access.
                  Useful after changing image processing settings.
                </p>
              </div>
              <button
                phx-click="clear_thumbnail_cache"
                data-confirm="Clear all cached thumbnails? They will regenerate automatically on next access."
                class="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white text-sm font-medium rounded-lg transition-colors"
              >
                Clear Cache
              </button>
            </div>
          </div>
        </div>

        <div>
          <h2 class="text-xl font-bold uppercase mb-6 text-gray-300">Current Biennale</h2>

          <%= if @current_biennale do %>
            <.link
              navigate={~p"/admin/biennales/#{@current_biennale.id}"}
              class="block p-6 bg-gray-900/50 border border-gray-800 rounded-lg hover:border-gray-700 transition-all group"
            >
              <div class="flex items-center justify-between">
                <div>
                  <h3 class="text-lg font-bold text-white group-hover:text-purple-400 transition-colors">
                    {@current_biennale.fields["year"]} - {@current_biennale.fields["theme"]}
                  </h3>
                  <%= if @current_biennale.fields["start_date"] && @current_biennale.fields["end_date"] do %>
                    <p class="text-sm text-gray-500 mt-1">
                      {format_date(@current_biennale.fields["start_date"], "%B %d")} – {format_date(
                        @current_biennale.fields["end_date"],
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
          <% else %>
            <div class="text-center py-12 border border-gray-800 rounded-lg">
              <p class="text-gray-500 mb-4">No biennales created yet.</p>
              <.link
                navigate={~p"/admin/biennales/new"}
                class="inline-block px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-bold uppercase tracking-wider rounded-lg transition-colors"
              >
                Create First Biennale
              </.link>
            </div>
          <% end %>
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

  defp format_bytes(bytes) when bytes >= 1_000_000_000,
    do: "#{Float.round(bytes / 1_000_000_000, 1)} GB"

  defp format_bytes(bytes) when bytes >= 1_000_000, do: "#{Float.round(bytes / 1_000_000, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1_000, do: "#{Float.round(bytes / 1_000, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"
end
