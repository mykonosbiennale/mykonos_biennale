defmodule MykonosBiennale.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MykonosBiennaleWeb.Telemetry,
      MykonosBiennale.Repo,
      {DNSCluster, query: Application.get_env(:mykonos_biennale, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MykonosBiennale.PubSub},
      # Start a worker by calling: MykonosBiennale.Worker.start_link(arg)
      # {MykonosBiennale.Worker, arg},
      # Start to serve requests, typically the last entry
      MykonosBiennaleWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MykonosBiennale.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MykonosBiennaleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
