defmodule HamsatWeb.Dashboard.Components.AlertsList do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias HamsatWeb.Dashboard.Components.AlertItem

  def mount(socket) do
    socket =
      socket
      |> assign(:mine?, false)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_alerts()

    {:ok, socket}
  end

  defp assign_alerts(socket) do
    if changed?(socket, :alerts_filter) do
      alerts = Alerts.list_alerts(socket.assigns.context, socket.assigns.alerts_filter)
      assign(socket, :alerts, alerts)
    else
      socket
    end
  end
end
