defmodule Hamsat.PassPlot do
  defstruct [:location, :pass, :satrec, coords: []]

  alias Hamsat.Coord
  alias Hamsat.Util

  @doc """
  Returns a list of `%{az: ..., el: ...}` sky coordinates for a satellite as
  seen by an observer between two times, without needing a full plot struct.
  """
  def sky_coords(satrec, observer, start_time, end_time, num_points \\ 20) do
    duration = DateTime.diff(end_time, start_time)

    if duration <= 0 do
      []
    else
      for i <- 0..num_points do
        time = DateTime.add(start_time, div(duration * i, num_points))
        pos = Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(time), magnitude?: false)
        %{az: pos.azimuth_in_degrees, el: pos.elevation_in_degrees}
      end
    end
  end

  @doc """
  Returns a list of `[lat, lon]` sub-satellite points between two times, for
  drawing a pass ground track on a map. Longitudes are kept within 180° of the
  previous point so a polyline doesn't jump across the antimeridian.
  """
  def ground_track(satrec, observer, start_time, end_time, num_points \\ 40)

  def ground_track(nil, _observer, _start_time, _end_time, _num_points), do: []

  def ground_track(satrec, observer, start_time, end_time, num_points) do
    duration = DateTime.diff(end_time, start_time)

    if duration <= 0 do
      []
    else
      for i <- 0..num_points do
        time = DateTime.add(start_time, div(duration * i, num_points))
        pos = Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(time), magnitude?: false)
        {pos.latitude, pos.longitude}
      end
      |> unwrap_track()
    end
  end

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

  def populate_coords(%__MODULE__{} = plot, opts \\ []) do
    start_time = opts[:start_time] || Timex.to_datetime(plot.pass.start_time)
    end_time = opts[:end_time] || Timex.to_datetime(plot.pass.end_time)
    num_points = opts[:points] || 40

    observer = Coord.to_observer(plot.location)
    duration = Timex.diff(end_time, start_time, :seconds)
    step = duration / num_points

    coords =
      Enum.map(0..num_points, fn i ->
        time = Timex.shift(start_time, seconds: trunc(i * step))
        pos = Satellite.Passes.current_position(plot.satrec, observer, Timex.to_erl(time), magnitude?: false)
        %{az: pos.azimuth_in_degrees, el: pos.elevation_in_degrees}
      end)

    %{plot | coords: coords}
  end
end
