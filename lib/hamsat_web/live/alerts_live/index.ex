defmodule HamsatWeb.AlertsLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias HamsatWeb.Alerts.Components.AlertTableRow

  state :alerts
  state :duration
  state :filter
  state :now, default: DateTime.utc_now()
  state :page_title, default: "Activations"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :set_now, 1_000)
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
    end

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    filter = [date: parse_date_filter(params)]
    alerts = Alerts.list_alerts(socket.assigns.context, filter)

    duration = if filter[:date] == :upcoming, do: :upcoming, else: :browse

    {:noreply,
     put_state(socket,
       filter: filter,
       alerts: alerts,
       duration: duration
     )}
  end

  defp parse_date_filter(params) do
    with %{"date" => date_string} <- params,
         {:ok, date} <- Date.from_iso8601(date_string) do
      date
    else
      _ -> :upcoming
    end
  end

  def handle_event("select", %{"id" => "interval", "selected" => "upcoming"}, socket) do
    {:noreply, push_patch(socket, to: ~p"/alerts")}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "browse"}, socket) do
    {:noreply, push_patch(socket, to: browse_path(socket.assigns.context.timezone))}
  end

  def handle_event("date-changed", params, socket) do
    params = Map.take(params, ["date"])
    socket = push_patch(socket, to: ~p"/alerts?#{params}")

    {:noreply, socket}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:noreply, put_state(socket, now: DateTime.utc_now())}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    {:noreply,
     put_state(
       socket,
       alerts: Alerts.patch_alerts(socket.assigns.alerts, socket.assigns.context, message)
     )}
  end

  defp duration_options do
    [upcoming: "Upcoming", browse: "Browse"]
  end

  defp browse_path(timezone) do
    params = %{date: timezone |> Timex.today() |> Date.to_iso8601()}
    ~p"/alerts?#{params}"
  end
end
