defmodule MykonosBiennaleWeb.ArchiveLive do
  use MykonosBiennaleWeb, :live_view
  alias MykonosBiennale.Content

  @impl true
  def mount(_params, _session, socket) do
    biennales = Content.list_biennales()

    {:ok,
     socket
     |> assign(:page_title, "Archive")
     |> assign(:biennales, biennales)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-black text-white">
        <%!-- Header --%>
        <div class="px-6 py-20 md:py-32">
          <div class="max-w-7xl mx-auto">
            <.link
              navigate={~p"/"}
              class="text-sm text-gray-400 hover:text-white uppercase tracking-wider mb-8 inline-block"
            >
              ← Back to Home
            </.link>

            <h1 class="text-4xl md:text-6xl font-bold uppercase mb-8">
              Archive
            </h1>

            <p class="text-lg text-gray-400 max-w-2xl">
              Explore past editions of the Mykonos Biennale, documenting over a decade of
              international contemporary art, performance, and experimental cinema.
            </p>
          </div>
        </div>

        <%!-- Biennale Grid --%>
        <div class="px-6 pb-20 md:pb-32">
          <div class="max-w-7xl mx-auto">
            <%= if @biennales == [] do %>
              <div class="text-center py-20">
                <p class="text-2xl text-gray-500">No biennales in the archive yet.</p>
              </div>
            <% else %>
              <div class="grid grid-cols-2 md:grid-cols-4 gap-8">
                <%= for biennale <- @biennales do %>
                  <.biennale_card biennale={biennale} />
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Footer --%>
        <div class="px-6 py-12 border-t border-gray-800">
          <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
            <div class="text-center md:text-left">
              <p class="text-sm text-gray-400 uppercase tracking-wider">
                Mykonos Biennale © 2025
              </p>
            </div>

            <div class="flex gap-6">
              <.link
                navigate={~p"/about"}
                class="text-sm text-gray-400 hover:text-white uppercase tracking-wider"
              >
                About
              </.link>
              <a href="#" class="text-sm text-gray-400 hover:text-white uppercase tracking-wider">
                Contact
              </a>
              <a href="#" class="text-sm text-gray-400 hover:text-white uppercase tracking-wider">
                Press
              </a>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp biennale_card(assigns) do
    ~H"""
    <.link
      navigate={~p"/biennale/#{@biennale.slug}"}
      class="group block bg-gray-900 border border-gray-800 hover:border-gray-600 transition-all duration-300"
    >
      <div class="aspect-square bg-black relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-gray-800 to-black group-hover:scale-105 transition-transform duration-500">
        </div>
        <div class="absolute inset-0 flex items-center justify-center">
          <span class="text-6xl md:text-7xl font-bold text-gray-600 group-hover:text-gray-400 transition-colors">
            {@biennale.fields["year"]}
          </span>
        </div>
      </div>

      <div class="p-6">
        <h3 class="text-2xl font-bold uppercase mb-2 group-hover:text-gray-300 transition-colors">
          {@biennale.fields["theme"]}
        </h3>

        <%= if @biennale.fields["statement"] do %>
          <p class="text-gray-400 text-sm line-clamp-3">
            {@biennale.fields["statement"]}
          </p>
        <% end %>

        <%= if @biennale.fields["start_date"] && @biennale.fields["end_date"] do %>
          <p class="text-xs text-gray-500 mt-4 uppercase tracking-wider">
            {Calendar.strftime(Date.from_iso8601!(@biennale.fields["start_date"]), "%B %d")} – {Calendar.strftime(
              Date.from_iso8601!(@biennale.fields["end_date"]),
              "%B %d, %Y"
            )}
          </p>
        <% end %>
      </div>
    </.link>
    """
  end
end
