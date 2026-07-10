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
     |> assign(:results, Search.search(q, limit: 20))}
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

  defp empty_results, do: %{biennales: [], events: [], participants: [], artworks: [], films: [], performances: [], total: 0}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-black text-white">
        <%!-- Header --%>
        <div class="px-6 py-6 border-b border-gray-800">
          <div class="max-w-7xl mx-auto">
            <.link
              navigate={~p"/"}
              class="text-sm text-gray-400 hover:text-white uppercase tracking-wider mb-2 inline-block"
            >
              ← Back to Home
            </.link>

            <h1 class="text-xl font-bold uppercase tracking-tight">
              Search
            </h1>
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

                <%= if @results.biennales != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Biennales
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.biennales}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.events != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Events
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.events}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.participants != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Participants
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.participants}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <div :if={hit.creators != []} class="text-sm text-gray-400">
                            {Enum.join(hit.creators, " · ")}
                          </div>
                          <div :if={hit.events != []} class="text-xs text-gray-500 mt-1">
                            {Enum.join(hit.events, " · ")}
                          </div>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.artworks != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Artworks
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.artworks}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <div :if={hit.creators != []} class="text-sm text-gray-400">
                            {Enum.join(hit.creators, ", ")}
                          </div>
                          <div :if={hit.events != []} class="text-xs text-gray-500 mt-1">
                            {Enum.join(hit.events, " · ")}
                          </div>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.films != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Short Films and Videos
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.films}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <div :if={hit.creators != []} class="text-sm text-gray-400">
                            {Enum.join(hit.creators, ", ")}
                          </div>
                          <div :if={hit.events != []} class="text-xs text-gray-500 mt-1">
                            {Enum.join(hit.events, " · ")}
                          </div>
                        </.link>
                      </li>
                    </ul>
                  </section>
                <% end %>

                <%= if @results.performances != [] do %>
                  <section class="mb-12">
                    <h2 class="text-2xl font-bold uppercase mb-6 text-gray-300">
                      Performances
                    </h2>
                    <ul class="space-y-4">
                      <li :for={hit <- @results.performances}>
                        <.link
                          navigate={hit.url}
                          class="block border border-gray-800 p-5 hover:border-white hover:bg-gray-950 transition-colors"
                        >
                          <div class="flex items-baseline justify-between gap-4 mb-1">
                            <h3 class="text-lg font-bold text-white">{hit.title}</h3>
                            <span
                              :if={hit.subtitle}
                              class="text-xs text-gray-500 uppercase tracking-wider whitespace-nowrap"
                            >
                              {hit.subtitle}
                            </span>
                          </div>
                          <div :if={hit.creators != []} class="text-sm text-gray-400">
                            {Enum.join(hit.creators, ", ")}
                          </div>
                          <div :if={hit.events != []} class="text-xs text-gray-500 mt-1">
                            {Enum.join(hit.events, " · ")}
                          </div>
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
