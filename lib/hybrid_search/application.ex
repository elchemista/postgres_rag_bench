defmodule HybridSearch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HybridSearchWeb.Telemetry,
      HybridSearch.Repo,
      {DNSCluster, query: Application.get_env(:hybrid_search, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HybridSearch.PubSub},
      # Start a worker by calling: HybridSearch.Worker.start_link(arg)
      # {HybridSearch.Worker, arg},
      # Start to serve requests, typically the last entry
      HybridSearchWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HybridSearch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HybridSearchWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
