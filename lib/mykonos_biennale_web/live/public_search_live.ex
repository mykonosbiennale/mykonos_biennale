defmodule MykonosBiennaleWeb.PublicSearchLive do
  use MykonosBiennaleWeb, :live_view

  alias MykonosBiennale.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Search")
     |> assign(:q, "")
     |> assign(:results, empty_results())}
  end

  @impl true
  def handle_params(%{"q" => q}, _uri, socket) when is_binary(q) and q != "" do
    {:noreply,
     socket
     |> assign(:q, q)
     |> assign(:page_title, "Search · #{q}")
     |> assign(:results, Search.search(q, limit: 50))}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:q, "")
     |> assign(:results, empty_results())}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, push_patch(socket, to: ~p"/search?#{[q: q]}")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/search")}
  end

  defp empty_results, do: %{entities: [], media: [], total: 0}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-black text-white">
        <%!-- Header --%>
        <div class="px-6 py-12 md:py-16 border-b border-gray-800">
          <div class="max-w-7xl mx-auto">
            <.link
              navigate={~p"/"}
              class="text-sm text-gray-400 hover:text-white uppercase tracking-wider mb-8 inline-block"
            >
              ← Back to Home
            </.link>

            <h1 class="text-4xl md:text-6xl font-bold uppercase tracking-tight mb-8">
              Search
            </h1>

            <form phx-submit="search" class="flex gap-3">
              <input
                type="text"
                name="q"
                value={@q}
                placeholder="Search artists, artworks, films, events…"
                autofocus
                autocomplete="off"
                class="flex-1 bg-black border-2 border-white text-white text-lg px-4 py-3 placeholder-gray-500 focus:outline-none focus:border-gray-300"
              />
              <button
                type="submit"
                class="px-6 py-3 bg-white text-black font-bold uppercase tracking-wider hover:bg-gray-200 transition-colors"
              >
                Search
              </button>
              <button
                :if={@q != ""}
                type="button"
                phx-click="clear"
                class="px-6 py-3 border-2 border-white text-white font-bold uppercase tracking-wider hover:bg-white hover:text-black transition-colors"
              >
                Clear
              </button>
            </form>
          </div>
        </div>

        <%!-- Results --%>
        <div class="px-6 py-12 md:py-16">
          <div class="max-w-7xl mx-auto">
            <%= cond do %>
              <% @q == "" -> %>
                <p class="text-gray-400 text-lg">Type a name, work, or theme to begin.</p>
              <% @results.total == 0 -> %>
                <p class="text-gray-400 text-lg">
                  No results for <span class="text-white font-bold">"{@q}"</span>.
                </p>
              <% true -> %>
                <p class="text-sm text-gray-400 uppercase tracking-wider mb-8">
                  {@results.total} result{if @results.total != 1, do: "s"} for "{@q}"
                </p>

                <%= if @results.entities != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Archive
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.entities}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-2">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <p :if={hit.snippet != ""} class="text-sm text-gray-400 leading-relaxed">
                            {hit.snippet}
                          </p>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.media != [] do %>
                  <section>
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Media
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.media}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-2">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <p :if={hit.snippet != ""} class="text-sm text-gray-400 leading-relaxed">
                            {hit.snippet}
                          </p>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
