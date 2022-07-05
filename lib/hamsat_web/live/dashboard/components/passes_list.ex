defmodule HamsatWeb.Dashboard.Components.PassesList do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias HamsatWeb.Dashboard.Components.AlertItem

  def mount(socket) do
    socket =
      socket
      |> assign_pass_opts()

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_passes()

    {:ok, socket}
  end

  defp assign_pass_opts(socket) do
    assign(socket, :pass_opts, [])
  end

  defp assign_passes(socket) do
    # if changed?(socket, :pass_opts) do
    #   alerts = Alerts.list_alerts(socket.assigns.context, socket.assigns.alert_filter)
    #   assign(socket, :alerts, alerts)
    # else
    #   socket
    # end
    socket
  end
end
