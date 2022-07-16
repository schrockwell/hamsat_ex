defmodule HamsatWeb.Dashboard.ShowLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias HamsatWeb.Dashboard.Components.AlertsList
  alias HamsatWeb.Dashboard.Components.PassesList

  def mount(_params, _session, socket) do
    Process.send_after(self(), :set_now, 1_000)
    schedule_reload_alerts()

    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign_now()
     |> assign_my_alerts_filter()
     |> assign_upcoming_alerts_filter()
     |> assign_upcoming_alert_count()}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:noreply, assign_now(socket)}
  end

  def handle_info(:reload_alerts, socket) do
    schedule_reload_alerts()

    {:noreply,
     socket
     |> assign_my_alerts_filter()
     |> assign_upcoming_alerts_filter()}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_now(socket) do
    assign(socket, :now, DateTime.utc_now())
  end

  defp assign_upcoming_alerts_filter(socket) do
    assign(socket, :upcoming_alerts_filter,
      after: DateTime.utc_now(),
      before: Timex.shift(DateTime.utc_now(), days: 1),
      limit: 100
    )
  end

  defp assign_my_alerts_filter(%{assigns: %{context: %{user: :guest}}} = socket) do
    assign(socket, :my_alerts_filter, nil)
  end

  defp assign_my_alerts_filter(socket) do
    assign(socket, :my_alerts_filter,
      after: DateTime.utc_now(),
      user_id: socket.assigns.context.user.id
    )
  end

  defp assign_upcoming_alert_count(socket) do
    assign(socket, :upcoming_alert_count, Alerts.count_alerts(date: :upcoming))
  end

  defp schedule_reload_alerts do
    Process.send_after(self(), :reload_alerts, :timer.minutes(1))
  end
end
