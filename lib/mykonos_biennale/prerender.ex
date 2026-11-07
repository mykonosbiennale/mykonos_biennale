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
  def handle_info(:regenerate, state) do
    paths = public_paths()

    Enum.each(paths, &PhoenixPrerender.Regenerator.maybe_regenerate(&1, @endpoint))
    prune_removed_biennales(paths)

    {:noreply, %{state | timer: nil}}
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
