defmodule HamsatWeb.Alerts.IndexLive do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts

  def mount(_params, _session, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:ok, assign(socket, :now, DateTime.utc_now())}
  end

  def handle_params(params, _uri, socket) do
    filter = [date: parse_date_filter(params)]
    alerts = Alerts.list_alerts(socket.assigns.context, filter)

    duration = if filter[:date] == :upcoming, do: :upcoming, else: :browse

    # browse_link_to =
    #   if filter[:date] == :upcoming,
    #     do: Routes.alerts_path(socket, :index, date: Date.utc_today() |> Date.to_iso8601())

    socket =
      socket
      |> assign(:filter, filter)
      |> assign(:alerts, alerts)
      |> assign(:duration, duration)

    # |> assign(:browse_link_to, browse_link_to)

    {:noreply, socket}
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
    {:noreply, push_patch(socket, to: Routes.alerts_path(socket, :index))}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "browse"}, socket) do
    {:noreply, push_patch(socket, to: browse_url(socket))}
  end

  def handle_event("date-changed", params, socket) do
    params = Map.take(params, ["date"])
    socket = push_patch(socket, to: Routes.alerts_path(socket, :index, params))

    {:noreply, socket}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  defp duration_options do
    [upcoming: "Upcoming", browse: "Browse"]
  end

  defp browse_url(socket) do
    default_date = Date.utc_today() |> Timex.shift(days: 1) |> Date.to_iso8601()
    Routes.alerts_path(socket, :index, date: default_date)
  end
end
