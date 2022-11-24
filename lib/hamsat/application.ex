defmodule Hamsat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Hamsat.Repo,
      # Start the Telemetry supervisor
      HamsatWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Hamsat.PubSub},
      Hamsat.Scheduler,
      # Start the Endpoint (http/https)
      HamsatWeb.Endpoint
      # Start a worker by calling: Hamsat.Worker.start_link(arg)
      # {Hamsat.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Hamsat.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      Hamsat.Alerts.PassCache.initialize()
      Hamsat.Satellites.sync()
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
