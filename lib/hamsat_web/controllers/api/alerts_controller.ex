defmodule HamsatWeb.API.AlertsController do
  use HamsatWeb, :controller

  def upcoming(conn, params) do
    format = if params["format"] == "cloudlog", do: :cloudlog, else: :default

    alerts = Hamsat.Alerts.list_alerts(conn.assigns.context, date: :upcoming)
    render(conn, "index.json", alerts: alerts, format: format)
  end
end
