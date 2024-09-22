defmodule Hamsat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hamsat.Repo,
      HamsatWeb.Telemetry,
      {Phoenix.PubSub, name: Hamsat.PubSub},
      Hamsat.Scheduler,
      Hamsat.Satellites.PositionServer,
      Hamsat.Satellites.PeriodicSync,
      HamsatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hamsat.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      Hamsat.Alerts.PassCache.initialize()
      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HamsatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
