defmodule ElvenCouncil.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ElvenCouncilWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:elven_council, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ElvenCouncil.PubSub},
      {Registry, keys: :unique, name: ElvenCouncil.GameRegistry},
      # Start to serve requests, typically the last entry
      ElvenCouncilWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ElvenCouncil.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ElvenCouncilWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
