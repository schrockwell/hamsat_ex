defmodule Hamsat.PassPlot do
  defstruct [:location, :pass, :satrec, coords: []]

  alias Hamsat.Coord

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

    %{plot | coords: coords} |> IO.inspect()
  end
end
