defmodule HamsatWeb.Dashboard.Components.AlertsList do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias HamsatWeb.Dashboard.Components.AlertItem

  def mount(socket) do
    socket =
      socket
      |> assign_alert_filter()

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_alerts()

    {:ok, socket}
  end

  defp assign_alert_filter(socket) do
    assign(socket, :alert_filter,
      after: DateTime.utc_now(),
      before: Timex.shift(DateTime.utc_now(), days: 1),
      limit: 100
    )
  end

  defp assign_alerts(socket) do
    if changed?(socket, :alert_filter) do
      alerts = Alerts.list_alerts(socket.assigns.context, socket.assigns.alert_filter)
      assign(socket, :alerts, alerts)
    else
      socket
    end
  end
end
