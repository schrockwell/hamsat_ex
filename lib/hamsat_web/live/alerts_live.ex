defmodule HamsatWeb.AlertsLive do
  use HamsatWeb, :live_view

  alias Hamsat.Satellites
  alias Hamsat.Alerts

  def mount(_params, _session, socket) do
    socket = socket |> assign_passes()

    {:ok, socket}
  end

  def handle_event("create_alert", %{"pass_id" => pass_id}, socket) do
    pass = Enum.find(socket.assigns.passes, &(&1.id == pass_id))

    Alerts.create_alert(socket.assigns.context, pass, %{callsign: "WW1X"})

    {:noreply, assign_passes(socket)}
  end

  defp assign_passes(socket) do
    sats = Satellites.list_satellites()
    passes = Alerts.list_all_passes(socket.assigns.context, sats, count: 1)

    assign(socket, :passes, passes)
  end
end
