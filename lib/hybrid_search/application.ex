defmodule HybridSearch.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        HybridSearch.Repo
      ] ++ telemetry_child()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HybridSearch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp telemetry_child do
    if Code.ensure_loaded?(HybridSearchWeb.Telemetry) do
      [HybridSearchWeb.Telemetry]
    else
      []
    end
  end
end
