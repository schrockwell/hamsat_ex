defmodule HamsatWeb.Alerts.ShowLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat
  alias HamsatWeb.LocationSetter
  alias HamsatWeb.SatTracker

  def mount(%{"id" => alert_id}, _session, socket) do
    alert = Alerts.get_alert!(socket.assigns.context, alert_id)

    socket =
      socket
      |> assign(:alert, alert)
      |> assign(:activator_coord, %Coord{lat: alert.observer_lat, lon: alert.observer_lon})
      |> assign_markers()
      |> assign_tick()
      |> schedule_tick()
      |> assign_tweet_url()
      |> assign_satmatch_url()

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> assign_tick()
      |> schedule_tick()

    {:noreply, socket}
  end

  defp schedule_tick(socket) do
    # Stop ticking once alert LOS has passed
    # if DateTime.compare(socket.assigns.alert.los_at, DateTime.utc_now()) == :gt do
    Process.send_after(self(), :tick, :timer.seconds(1))
    # end

    socket
  end

  defp assign_markers(socket) do
    alert = socket.assigns.alert

    if alert.is_workable? do
      start_style = "left: #{progress(alert, alert.workable_start_at) * 100}%"
      end_style = "right: #{(1.0 - progress(alert, alert.workable_end_at)) * 100}%"

      socket
      |> assign(:workable_start_marker_style, start_style)
      |> assign(:workable_end_marker_style, end_style)
    else
      socket
      |> assign(:workable_start_marker_style, nil)
      |> assign(:workable_end_marker_style, nil)
    end
  end

  defp assign_tick(socket) do
    alert = socket.assigns.alert
    now = DateTime.utc_now()
    progress = max(min(progress(alert, now), 1.05), -0.05)

    progression = Alert.progression(alert, now)
    events = Alert.events(alert, now)

    cursor_class =
      case progression do
        :upcoming -> "bg-gray-200"
        :passed -> "bg-gray-200"
        :before_workable -> "bg-gray-400"
        :after_workable -> "bg-gray-400"
        :in_progress -> "bg-gray-400"
        :workable -> "bg-emerald-500"
      end

    my_sat_position =
      if socket.assigns.context.location do
        alert.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(socket.assigns.context.location))
      end

    activator_sat_position =
      if socket.assigns.context.location do
        alert.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(
          Coord.to_observer(%Coord{lat: alert.observer_lat, lon: alert.observer_lon})
        )
      end

    socket
    |> assign(:now, now)
    |> assign(:cursor_style, "left: #{progress * 100}%")
    |> assign(:cursor_class, cursor_class)
    |> assign(:progression, progression)
    |> assign(:my_sat_position, my_sat_position)
    |> assign(:activator_sat_position, activator_sat_position)
    |> assign(:events, events)
  end

  defp progress(alert, now) do
    duration = DateTime.diff(alert.los_at, alert.aos_at)
    after_aos = DateTime.diff(now, alert.aos_at)
    after_aos / duration
  end

  defp progression_class(:workable, :workable),
    do:
      "uppercase px-4 py-2 border-2 border-emerald-500 bg-emerald-100 text-emerald-600 font-medium"

  defp progression_class(match, match),
    do: "uppercase px-4 py-2 border-2 border-gray-300 bg-gray-100 text-gray-600 font-medium"

  defp progression_class(_, _),
    do: "uppercase px-4 py-2 border text-gray-400"

  defp elevation_class(elevation) when elevation <= 0, do: "text-red-600"
  defp elevation_class(_), do: nil

  defp event_timer(event, now, passed \\ "") do
    cond do
      # event.event == :passed and DateTime.event.end_at, now) :lt -> passed
      DateTime.compare(event.end_at, now) == :lt -> passed
      DateTime.compare(event.start_at, now) == :gt -> "in #{duration(now, event.start_at)}"
      true -> "for #{duration(now, event.end_at)}"
    end
  end

  defp assign_tweet_url(socket) do
    alert = socket.assigns.alert
    url = URI.encode(Routes.alerts_url(socket, :show, alert.id))
    grid = Grid.encode!(alert.observer_lat, alert.observer_lon, 6)

    freq =
      case {alert.downlink_mhz, alert.mode} do
        {nil, nil} -> nil
        {mhz, nil} -> "📻 #{mhz(mhz)}"
        {nil, mode} -> "📻 #{mode}"
        {mhz, mode} -> "📻 #{mhz(mhz)} #{mode}"
      end

    comment =
      if alert.comment do
        "📢 #{alert.comment}"
      end

    text =
      [
        "🛰 #{alert.callsign} on #{alert.sat.name}",
        "⏰ #{date(:utc, alert.aos_at)} from #{short_time(:utc, alert.aos_at)}Z to #{short_time(:utc, alert.los_at)}Z",
        "🗺 #{grid}",
        freq,
        comment,
        "👀 #{url}"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
      |> URI.encode()

    assign(socket, :tweet_url, "https://twitter.com/intent/tweet?text=#{text}")
  end

  defp assign_satmatch_url(socket) do
    satname = socket.assigns.alert.sat.nasa_name
    obs1 = Grid.encode!({socket.assigns.alert.observer_lat, socket.assigns.alert.observer_lon}, 6)

    obs2 =
      if socket.assigns.context.location,
        do: Grid.encode!(socket.assigns.context.location, 6)

    # SatMatch searches for passes AFTER the specified datetime, so give it a grace
    # period to ensure that it finds the desired pass
    timestamp = socket.assigns.alert.aos_at |> Timex.shift(minutes: -10) |> DateTime.to_iso8601()

    url =
      if obs1 != obs2 and obs2 != nil do
        "https://www.satmatch.com/satellite/#{satname}/obs1/#{obs1}/obs2/#{obs2}/pass/#{timestamp}"
      else
        "https://satmatch.com/satellite/#{satname}/obs1/#{obs1}/pass/#{timestamp}"
      end

    assign(socket, :satmatch_url, url)
  end
end
