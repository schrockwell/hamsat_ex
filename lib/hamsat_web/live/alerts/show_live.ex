defmodule HamsatWeb.Alerts.ShowLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts

  def mount(%{"id" => alert_id}, _session, socket) do
    alert = Alerts.get_alert!(socket.assigns.context, alert_id)

    socket =
      socket
      |> assign(:alert, alert)
      |> assign_cursor()

    if connected?(socket), do: schedule_tick()

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    schedule_tick()

    socket =
      socket
      |> assign_cursor()

    {:noreply, socket}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, :timer.seconds(1))
  end

  defp assign_cursor(socket) do
    now = DateTime.utc_now()
    duration = DateTime.diff(socket.assigns.alert.los_at, socket.assigns.alert.aos_at)
    after_aos = DateTime.diff(now, socket.assigns.alert.aos_at)
    progress = after_aos / duration

    progress = max(min(progress, 1.05), -0.05)

    assign(socket, :cursor_style, "left: #{progress * 100}%")
  end
end
