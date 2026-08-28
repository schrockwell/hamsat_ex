defmodule HamsatWeb.PassesLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.PassPlot
  alias Hamsat.Passes
  alias Hamsat.Schemas.Sat
  alias Hamsat.Util
  alias HamsatWeb.LiveComponents.PassTracker
  alias HamsatWeb.SatTracker

  on_mount HamsatWeb.Live.NowTicker

  def mount(%{"hash" => hash}, _session, socket) do
    case Passes.fetch_pass_by_hash(hash) do
      {:ok, pass} ->
        grid = Grid.encode!(observer_coord(pass), 6)

        {:ok,
         socket
         |> assign(:page_title, "#{pass.sat.name} pass over #{grid}")
         |> assign(pass: pass, sat: pass.sat, grid: grid, coord: observer_coord(pass))
         |> assign_pass_plot()
         |> assign_ground_track()}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Sorry, that pass could not be found.")
         |> redirect(to: ~p"/passes")}
    end
  end

  defp assign_pass_plot(socket) do
    pass = socket.assigns.pass
    satrec = Sat.get_satrec(pass.sat)

    pass_plot = %PassPlot{
      satrec: satrec,
      location: observer_coord(pass),
      coords: PassPlot.sky_coords(satrec, pass.observer, aos_at(pass), los_at(pass), 40)
    }

    assign(socket, pass_plot: pass_plot)
  end

  # Sub-satellite [lat, lon] points between AOS and LOS, for drawing the
  # ground track on the map
  @ground_track_points 40

  defp assign_ground_track(socket) do
    pass = socket.assigns.pass
    satrec = Sat.get_satrec(pass.sat)
    start_time = aos_at(pass)
    duration = DateTime.diff(los_at(pass), start_time)

    coords =
      for i <- 0..@ground_track_points do
        time = DateTime.add(start_time, div(duration * i, @ground_track_points))

        pos =
          Satellite.Passes.current_position(satrec, pass.observer, Util.utc_datetime_to_erl(time), magnitude?: false)

        {pos.latitude, pos.longitude}
      end

    assign(socket, ground_track: unwrap_track(coords))
  end

  # Keep each longitude within 180° of the previous point so the polyline
  # doesn't jump across the antimeridian
  defp unwrap_track(coords) do
    coords
    |> Enum.map_reduce(nil, fn {lat, lon}, prev_lon ->
      lon =
        cond do
          prev_lon == nil -> wrap_lon(lon)
          lon - prev_lon > 180 -> lon - 360
          prev_lon - lon > 180 -> lon + 360
          true -> lon
        end

      {[lat, lon], lon}
    end)
    |> elem(0)
  end

  defp wrap_lon(lon) when lon > 180, do: lon - 360
  defp wrap_lon(lon), do: lon

  defp observer_coord(pass) do
    %Coord{lat: pass.observer.latitude_deg, lon: pass.observer.longitude_deg}
  end

  defp aos_at(pass), do: Util.erl_to_utc_datetime(pass.info.aos.datetime)
  defp los_at(pass), do: Util.erl_to_utc_datetime(pass.info.los.datetime)

  # The status chip next to the title: {label, timer, class}
  defp status(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming ->
        {"Upcoming", "rises in #{duration(now, aos_at(pass))}", "border-gray-300 bg-gray-100 text-gray-700"}

      :in_progress ->
        {"In progress", "sets in #{duration(now, los_at(pass))}", "border-emerald-500 bg-emerald-100 text-emerald-700"}

      :passed ->
        {"Passed", "#{Timex.from_now(los_at(pass), now)}", "border-gray-200 bg-gray-100 text-gray-400"}
    end
  end

  defp sat_position(pass, _now) do
    pass.sat
    |> Sat.get_satrec()
    |> Satellite.current_position(pass.observer, magnitude?: false)
  end

  defp elevation_class(elevation) when elevation <= 0, do: "text-red-600"
  defp elevation_class(_), do: "text-gray-800"

  # "Sat Aug 23 · 11:46 – 12:03 EDT", in the viewer's timezone
  defp when_text(context, pass) do
    aos = pass |> aos_at() |> Timex.to_datetime(context.timezone)
    los = pass |> los_at() |> Timex.to_datetime(context.timezone)

    date = Timex.format!(aos, "{WDshort} {Mshort} {D}")
    zone = Timex.format!(aos, "{Zabbr}")

    "#{date} · #{short_time(context, aos)} – #{short_time(context, los)} #{zone}"
  end

  # "435.030 – 435.156, 145.960 MHz" across all transponders, or "–" when none
  defp sat_freqs(sat, direction) do
    sat
    |> Sat.subbands(direction, [])
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&subband_range/1)
    |> Enum.uniq()
    |> case do
      [] -> "–"
      ranges -> Enum.join(ranges, ", ") <> " MHz"
    end
  end

  # "212° SW"
  defp az_text(event) do
    "#{round(event.azimuth_in_degrees)}° #{cardinal_direction(event.azimuth_in_degrees)}"
  end

  # Rise and set elevations round to 0° by definition
  defp el_text(event) do
    "#{max(round(event.elevation_in_degrees), 0)}°"
  end

  defp satmatch_url(pass) do
    # SatMatch searches for passes AFTER the specified datetime, so give it a
    # grace period to ensure that it finds the desired pass
    timestamp = pass |> aos_at() |> Timex.shift(minutes: -10) |> DateTime.to_iso8601()
    obs = Grid.encode!(observer_coord(pass), 6)

    "https://satmatch.com/satellite/#{pass.sat.nasa_name}/obs1/#{obs}/pass/#{timestamp}"
  end
end
