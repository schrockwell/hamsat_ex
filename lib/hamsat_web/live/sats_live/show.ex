defmodule HamsatWeb.SatsLive.Show do
  use HamsatWeb, :live_view

  import HamsatWeb.ActivationComponents
  import HamsatWeb.SatComponents, only: [sat_modulation_labels: 1]

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Grid
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Satellites.PositionServer
  alias Hamsat.Util

  alias HamsatWeb.SatTracker

  on_mount {HamsatWeb.Live.NowTicker, fingerprint: {__MODULE__, :now_fingerprint}}

  # Activation rows change style as they progress (see NowTicker)
  def now_fingerprint(assigns, now) do
    for alert <- assigns.alerts, do: {alert.id, Hamsat.Schemas.Alert.progression(alert, now)}
  end

  # Earth's gravitational parameter (km³/s²) and mean radius (km), for
  # deriving the orbit summary from the TLE's mean motion and eccentricity
  @mu 398_600.4418
  @earth_radius 6371.0

  def mount(%{"number" => number}, _session, socket) do
    sat = Satellites.get_satellite_by_number!(number)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "satellite_positions")
    end

    socket =
      socket
      |> assign(:page_title, sat.name)
      |> assign(sat: sat)
      |> assign(stats: Satellites.activation_stats(sat))
      |> assign(orbit: orbital_details(sat))
      |> assign_alerts()
      |> assign_passes()
      |> assign_sat_positions()

    {:ok, socket}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    {:noreply,
     assign(
       socket,
       alerts: Alerts.patch_alerts(socket.assigns.alerts, socket.assigns.context, message)
     )}
  end

  def handle_info({:satellite_positions, positions}, socket) do
    {:noreply, assign(socket, sat_positions: Enum.filter(positions, &(&1.sat_id == socket.assigns.sat.id)))}
  end

  defp assign_alerts(socket) do
    assign(
      socket,
      :alerts,
      Alerts.list_alerts(socket.assigns.context, sat_id: socket.assigns.sat.id, date: :upcoming)
    )
  end

  defp assign_passes(socket) do
    if socket.assigns.context.location do
      assign(
        socket,
        :passes,
        Passes.list_all_passes(socket.assigns.context, [socket.assigns.sat], ending: Timex.shift(Timex.now(), days: 1))
      )
    else
      assign(socket, :passes, [])
    end
  end

  defp assign_sat_positions(socket) do
    assign(socket,
      sat_positions: Enum.filter(PositionServer.get_sat_positions(), &(&1.sat_id == socket.assigns.sat.id))
    )
  end

  defp grid_label(context), do: Grid.encode!(context.location, 4)

  defp delimited(int) do
    int
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  # -- Transponders ------------------------------------------------

  defp transponder_mode(:linear), do: "Linear Transponder (Inverting)"
  defp transponder_mode(:linear_non_inv), do: "Linear Transponder (Non-Inverting)"
  defp transponder_mode(:fm), do: "FM Transponder"
  defp transponder_mode(:digital), do: "Digital Transponder"
  defp transponder_mode(:cw_beacon), do: "CW Beacon"
  defp transponder_mode(:telemetry), do: "Telemetry"
  defp transponder_mode(other), do: to_string(other)

  # -- Orbital details from the TLE -------------------------------------------

  # Parses the fixed-column TLE fields needed for the Details section. Returns
  # a map (values nil when unparsable) or nil when there is no usable TLE.
  defp orbital_details(sat) do
    with tle when is_binary(tle) <- sat.tle,
         [line1, line2] <- String.split(tle, "\n") do
      designator = intl_designator(line1)
      inclination = parse_float(String.slice(line2, 8, 8))
      eccentricity = parse_float("0." <> String.trim(String.slice(line2, 26, 7)))
      mean_motion = parse_float(String.slice(line2, 52, 11))

      {period_min, orbit} = orbit_from_elements(mean_motion, eccentricity)

      %{
        designator: designator,
        launch_year: launch_year(designator),
        inclination: inclination,
        period_min: period_min,
        orbit: orbit
      }
    else
      _ -> nil
    end
  end

  # "19096E" (TLE columns 10–17) → "2019-096E"
  defp intl_designator(line1) do
    case String.trim(String.slice(line1, 9, 8)) do
      <<yy::binary-size(2), rest::binary>> = raw ->
        case Integer.parse(yy) do
          {year, ""} -> "#{launch_century(year) + year}-#{rest}"
          _ -> raw
        end

      _ ->
        nil
    end
  end

  defp launch_century(year) when year >= 57, do: 1900
  defp launch_century(_year), do: 2000

  defp launch_year(nil), do: nil
  defp launch_year(designator), do: designator |> String.slice(0, 4)

  defp orbit_from_elements(mean_motion, eccentricity)
       when is_float(mean_motion) and mean_motion > 0 and is_float(eccentricity) do
    period_sec = 86_400 / mean_motion
    semi_major = :math.pow(@mu * :math.pow(period_sec / (2 * :math.pi()), 2), 1 / 3)
    perigee = semi_major * (1 - eccentricity) - @earth_radius
    apogee = semi_major * (1 + eccentricity) - @earth_radius

    {round(period_sec / 60), "#{delimited(round(perigee))} × #{delimited(round(apogee))} km"}
  end

  defp orbit_from_elements(_, _), do: {nil, nil}

  defp parse_float(string) do
    case Float.parse(String.trim(string)) do
      {float, _} -> float
      :error -> nil
    end
  end

  # -- Passes -----------------------------------------------------------------

  defp pass_aos_at(pass), do: Util.erl_to_utc_datetime(pass.info.aos.datetime)

  # "11:46 – 12:03", prefixed with a short weekday when beyond today
  defp pass_time_span(context, pass) do
    aos = pass_aos_at(pass)
    los = Util.erl_to_utc_datetime(pass.info.los.datetime)
    aos_local = Timex.to_datetime(aos, context.timezone)

    prefix =
      if Timex.to_date(aos_local) == Timex.today(context.timezone) do
        ""
      else
        Timex.format!(aos_local, "{WDshort} ")
      end

    prefix <> short_time(context, aos) <> " – " <> short_time(context, los)
  end

  # Countdown segments: "in 1:44" / "in 1d 1:00" until AOS; "now" once the
  # pass has started
  defp pass_countdown_segments(pass) do
    aos = pass_aos_at(pass)

    [
      %{until: aos, template: "in %s", to: aos, style: :countdown},
      %{until: nil, text: "now"}
    ]
  end

  # "212° SW → 38° NE"
  defp pass_azimuths(pass) do
    aos_az = pass.info.aos.azimuth_in_degrees
    los_az = pass.info.los.azimuth_in_degrees

    "#{round(aos_az)}° #{cardinal_direction(aos_az)} → #{round(los_az)}° #{cardinal_direction(los_az)}"
  end

  # Countdown segments for "Next pass over FN42 · today 11:46 · max 62°",
  # which becomes "· now until 12:03 ·" once the pass has started
  defp next_pass_caption_segments(context, [pass | _]) do
    aos = pass_aos_at(pass)
    los = Util.erl_to_utc_datetime(pass.info.los.datetime)
    aos_local = Timex.to_datetime(aos, context.timezone)

    day =
      if Timex.to_date(aos_local) == Timex.today(context.timezone),
        do: "today",
        else: Timex.format!(aos_local, "{WDshort}")

    caption = fn when_text ->
      "Next pass over #{grid_label(context)} · #{when_text} · max #{pass_max_el(pass)}"
    end

    [
      %{until: aos, text: caption.("#{day} #{short_time(context, aos)}")},
      %{until: nil, text: caption.("now until #{short_time(context, los)}")}
    ]
  end
end
