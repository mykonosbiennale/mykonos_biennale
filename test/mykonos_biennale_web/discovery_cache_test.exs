defmodule MykonosBiennaleWeb.DiscoveryCacheTest do
  # Changes the global TTL setting, so it cannot run alongside other tests.
  use ExUnit.Case, async: false

  alias MykonosBiennaleWeb.DiscoveryCache

  setup do
    DiscoveryCache.clear()

    on_exit(fn ->
      Application.put_env(:mykonos_biennale, :discovery_cache_ttl_ms, 0)
      DiscoveryCache.clear()
    end)

    :ok
  end

  test "reuses the built value while it is within the TTL" do
    Application.put_env(:mykonos_biennale, :discovery_cache_ttl_ms, :timer.hours(1))

    assert DiscoveryCache.fetch(:key, fn -> "first" end) == "first"
    assert DiscoveryCache.fetch(:key, fn -> "second" end) == "first"
  end

  test "rebuilds every time when the TTL is 0" do
    Application.put_env(:mykonos_biennale, :discovery_cache_ttl_ms, 0)

    assert DiscoveryCache.fetch(:key, fn -> "first" end) == "first"
    assert DiscoveryCache.fetch(:key, fn -> "second" end) == "second"
  end

  test "keeps separate values for separate keys" do
    Application.put_env(:mykonos_biennale, :discovery_cache_ttl_ms, :timer.hours(1))

    assert DiscoveryCache.fetch(:sitemap, fn -> "xml" end) == "xml"
    assert DiscoveryCache.fetch(:llms, fn -> "txt" end) == "txt"
  end
end
