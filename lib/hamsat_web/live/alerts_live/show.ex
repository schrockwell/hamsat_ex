defmodule HamsatWeb.AlertsLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Context
  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.PassMatch
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat
  alias HamsatWeb.LocationSetter
  alias HamsatWeb.SatTracker
  alias HamsatWeb.LiveComponents.PassTracker

  state :activator_coord
  state :activator_sat_position
  state :alert
  state :cursor_class
  state :cursor_style
  state :events
  state :my_sat_position
  state :now, default: DateTime.utc_now()
  state :pass_match
  state :progression
  state :satmatch_url
  state :tweet_url
  state :workable_end_marker_style
  state :workable_start_marker_style

  def mount(%{"id" => alert_id}, _session, socket) do
    alert = Alerts.get_alert!(socket.assigns.context, alert_id)

    pass_match =
      if socket.assigns.context.location do
        locations = [
          socket.assigns.context.location,
          %Coord{lat: alert.observer_lat, lon: alert.observer_lon}
        ]

        PassMatch.new(alert.sat, locations, alert.aos_at)
      end

    socket =
      socket
      |> put_state(alert: alert, pass_match: pass_match)
      |> schedule_tick()

    {:ok, socket}
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> put_state(now: DateTime.utc_now())
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

  @react to: :alert
  def assign_markers(socket) do
    alert = socket.assigns.alert

    if alert.is_workable? do
      start_style = "left: #{progress(alert, alert.workable_start_at) * 100}%"
      end_style = "right: #{(1.0 - progress(alert, alert.workable_end_at)) * 100}%"

      put_state(socket,
        workable_start_marker_style: start_style,
        workable_end_marker_style: end_style
      )
    else
      put_state(socket,
        workable_start_marker_style: nil,
        workable_end_marker_style: nil
      )
    end
  end

  @react to: [:alert, :now]
  def assign_tick(socket) do
    alert = socket.assigns.alert
    now = socket.assigns.now
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
        |> Satellite.current_position(Coord.to_observer(socket.assigns.context.location), magnitude?: false)
      end

    activator_sat_position =
      if socket.assigns.context.location do
        alert.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(%Coord{lat: alert.observer_lat, lon: alert.observer_lon}),
          magnitude?: false
        )
      end

    put_state(socket,
      activator_sat_position: activator_sat_position,
      cursor_class: cursor_class,
      cursor_style: "left: #{progress * 100}%",
      events: events,
      my_sat_position: my_sat_position,
      progression: progression
    )
  end

  defp progress(alert, now) do
    duration = DateTime.diff(alert.los_at, alert.aos_at)
    after_aos = DateTime.diff(now, alert.aos_at)
    after_aos / duration
  end

  defp progression_class(:workable, :workable),
    do: "uppercase px-4 py-2 border-2 border-emerald-500 bg-emerald-100 text-emerald-600 font-medium"

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

  @react to: :alert
  def assign_tweet_url(socket) do
    alert = socket.assigns.alert
    url = URI.encode(url(socket, ~p"/alerts/#{alert.id}"))
    grids = alert_grids(alert)

    freq =
      case {alert.mhz, alert.mode} do
        {nil, nil} -> nil
        {_mhz, nil} -> "📻 #{mhz(alert)}"
        {nil, mode} -> "📻 #{mode}"
        {_mhz, mode} -> "📻 #{mhz(alert)} #{mode}"
      end

    comment =
      if alert.comment do
        "📢 #{alert.comment}"
      end

    utc_context = %Context{}

    text =
      [
        "🛰 #{alert.callsign} on #{alert.sat.name}",
        "⏰ #{date(utc_context, alert.aos_at)} from #{short_time(utc_context, alert.aos_at)}Z to #{short_time(utc_context, alert.los_at)}Z",
        "🗺 #{grids}",
        freq,
        comment,
        "👀 #{url}"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")
      |> URI.encode()

    put_state(socket, tweet_url: "https://twitter.com/intent/tweet?text=#{text}")
  end

  @react to: :alert
  def assign_satmatch_url(socket) do
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

    put_state(socket, satmatch_url: url)
  end

  @react to: :alert
  def assign_activator_coord(socket) do
    put_state(socket,
      activator_coord: %Coord{
        lat: socket.assigns.alert.observer_lat,
        lon: socket.assigns.alert.observer_lon
      }
    )
  end
end
