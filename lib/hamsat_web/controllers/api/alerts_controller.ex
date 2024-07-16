defmodule HamsatWeb.API.AlertsController do
  use HamsatWeb, :controller

  def upcoming(conn, _params) do
    alerts = Hamsat.Alerts.list_alerts(conn.assigns.context, date: :upcoming)
    render(conn, "index.json", alerts: alerts)
  end
end
