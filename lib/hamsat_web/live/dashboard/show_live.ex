defmodule HamsatWeb.Dashboard.ShowLive do
  use HamsatWeb, :love_view

  alias Hamsat.Alerts
  alias HamsatWeb.Dashboard.Components.AlertsList

  state :my_alerts
  state :now, default: DateTime.utc_now()
  state :page_title, default: "Home"
  state :upcoming_alert_count
  state :upcoming_alerts

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :set_now, 1_000)
      schedule_reload_alerts()
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
    end

    {:ok,
     socket
     |> assign_my_alerts()
     |> assign_upcoming_alerts()
     |> assign_upcoming_alert_count()}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:noreply, put_state(socket, now: DateTime.utc_now())}
  end

  def handle_info(:reload_alerts, socket) do
    schedule_reload_alerts()

    {:noreply,
     socket
     |> assign_my_alerts()
     |> assign_upcoming_alerts()}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    socket =
      put_state(socket,
        my_alerts: Alerts.patch_alerts(socket.assigns.my_alerts, socket.assigns.context, message),
        upcoming_alerts:
          Alerts.patch_alerts(socket.assigns.upcoming_alerts, socket.assigns.context, message)
      )

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_upcoming_alerts(socket) do
    put_state(
      socket,
      upcoming_alerts:
        Alerts.list_alerts(socket.assigns.context,
          date: :upcoming,
          limit: 25
        )
    )
  end

  defp assign_my_alerts(%{assigns: %{context: %{user: :guest}}} = socket) do
    put_state(socket, my_alerts: nil)
  end

  defp assign_my_alerts(socket) do
    put_state(
      socket,
      my_alerts:
        Alerts.list_alerts(socket.assigns.context,
          after: DateTime.utc_now(),
          user_id: socket.assigns.context.user.id
        )
    )
  end

  defp assign_upcoming_alert_count(socket) do
    assign(socket, :upcoming_alert_count, Alerts.count_alerts(date: :upcoming))
  end

  defp schedule_reload_alerts do
    Process.send_after(self(), :reload_alerts, :timer.minutes(1))
  end
end
