defmodule Telecore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TelecoreWeb.Telemetry,
      Telecore.Repo,
      {DNSCluster, query: Application.get_env(:telecore, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Telecore.PubSub},
      # Start a worker by calling: Telecore.Worker.start_link(arg)
      # {Telecore.Worker, arg},
      # Start to serve requests, typically the last entry
      TelecoreWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Telecore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TelecoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
