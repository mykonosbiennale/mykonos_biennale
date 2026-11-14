defmodule MykonosBiennaleWeb.DiscoveryCache do
  @moduledoc """
  Keeps the generated sitemap.xml and llms.txt in memory.

  Each entry is rebuilt at most once per TTL (`:discovery_cache_ttl_ms`). Builds
  run inside this process, so concurrent requests for the same file wait for one
  build instead of each querying the database. A TTL of 0 disables caching.
  """

  use GenServer

  @name __MODULE__

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: @name)

  @doc "Returns the cached value for `key`, building it with `build_fun` when it is missing or stale."
  def fetch(key, build_fun) when is_function(build_fun, 0) do
    GenServer.call(@name, {:fetch, key, build_fun}, :infinity)
  end

  @doc "Drops every cached entry."
  def clear, do: GenServer.call(@name, :clear)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:fetch, key, build_fun}, _from, state) do
    now = System.monotonic_time(:millisecond)
    ttl = Application.get_env(:mykonos_biennale, :discovery_cache_ttl_ms, :timer.hours(1))

    case Map.get(state, key) do
      {value, built_at} when now - built_at < ttl ->
        {:reply, value, state}

      _stale_or_missing ->
        value = build_fun.()
        {:reply, value, Map.put(state, key, {value, now})}
    end
  end

  def handle_call(:clear, _from, _state), do: {:reply, :ok, %{}}
end
