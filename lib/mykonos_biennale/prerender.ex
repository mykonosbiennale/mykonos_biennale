defmodule MykonosBiennale.Prerender do
  @moduledoc """
  Keeps prerendered public pages in step with content changes.

  Any write to a content table schedules a debounced regeneration of the
  public pages. Regeneration runs through `PhoenixPrerender.Regenerator`,
  which serves the previous HTML until the fresh copy is written.
  """

  use GenServer

  alias MykonosBiennale.Content

  @endpoint MykonosBiennaleWeb.Endpoint
  @debounce_ms 2_000
  @boot_delay_ms 5_000
  @write_pattern ~r/^\s*(INSERT|UPDATE|DELETE)\b.*"(entities|entity_media|media|pages|sections|relationships|relationship_types|settings)"/is

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def flush_all, do: GenServer.cast(__MODULE__, :flush)

  @impl true
  def init(_opts) do
    if PhoenixPrerender.enabled?() do
      :telemetry.attach(
        "mykonos-biennale-prerender-writes",
        [:mykonos_biennale, :repo, :query],
        &__MODULE__.handle_query/4,
        nil
      )

      {:ok, %{timer: Process.send_after(self(), :regenerate, @boot_delay_ms)}}
    else
      {:ok, %{timer: nil}}
    end
  end

  @doc false
  def handle_query(_event, _measurements, %{query: query}, _config) when is_binary(query) do
    if Regex.match?(@write_pattern, query) do
      GenServer.cast(__MODULE__, :changed)
    end

    :ok
  end

  def handle_query(_event, _measurements, _metadata, _config), do: :ok

  @impl true
  def handle_cast(:changed, %{timer: nil} = state) do
    {:noreply, %{state | timer: Process.send_after(self(), :regenerate, @debounce_ms)}}
  end

  def handle_cast(:changed, state), do: {:noreply, state}

  @impl true
  def handle_cast(:flush, state) do
    clear_page_cache()
    regenerate(public_paths(), evict: true)
    {:noreply, state}
  end

  @impl true
  def handle_info(:regenerate, state) do
    regenerate(public_paths(), evict: true)
    {:noreply, %{state | timer: nil}}
  end

  defp regenerate(paths, evict: true) do
    Enum.each(paths, fn path ->
      evict(path)
      PhoenixPrerender.Regenerator.maybe_regenerate(path, @endpoint)
    end)

    prune_removed_biennales(paths)
  end

  # The prerender plug serves any file that exists, so the old copy must go
  # before a rebuild, or the rebuild just writes the old HTML back.
  defp evict(path) do
    file =
      PhoenixPrerender.Path.full_output_path(
        path,
        PhoenixPrerender.output_path(),
        PhoenixPrerender.url_style()
      )

    File.rm(file)
  end

  defp clear_page_cache do
    PhoenixPrerender.PageCache.clear()
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp public_paths do
    biennale_paths =
      Content.list_biennales()
      |> Enum.filter(& &1.visible)
      |> Enum.map(&"/biennale/#{&1.slug}")

    ["/", "/about", "/archive" | biennale_paths]
  end

  defp prune_removed_biennales(paths) do
    output_path = PhoenixPrerender.output_path()
    current = MapSet.new(paths)

    Path.wildcard(Path.join([output_path, "biennale", "*"]))
    |> Enum.reject(&MapSet.member?(current, "/biennale/#{Path.basename(&1)}"))
    |> Enum.each(&File.rm_rf!/1)
  end
end
