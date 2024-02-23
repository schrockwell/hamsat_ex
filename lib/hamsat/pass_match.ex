defmodule Hamsat.PassMatch do
  defstruct [:sat, :plots, :start_time, :end_time]

  alias Hamsat.Coord

  defmodule PassPlot do
    defstruct [:location, :pass, :satrec, coords: []]

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

  alias Hamsat.Coord
  alias Hamsat.Schemas.Sat

  def new(sat, locations, time, opts \\ []) do
    satrec = Sat.get_satrec(sat)

    %__MODULE__{
      sat: sat,
      plots: Enum.map(locations, &build_plot(satrec, &1, time))
    }
    |> populate_coords(opts)
  end

  defp build_plot(satrec, location, time) do
    observer = Coord.to_observer(location)
    pass = Satellite.next_pass(satrec, Timex.to_erl(time), observer, magnitude?: false)

    %PassPlot{satrec: satrec, location: location, pass: pass}
  end

  defp populate_coords(pass_match, opts) do
    match_start =
      pass_match.plots
      |> Enum.map(& &1.pass.start_time)
      |> Enum.max()
      |> Timex.to_datetime()

    match_end =
      pass_match.plots
      |> Enum.map(& &1.pass.end_time)
      |> Enum.min()
      |> Timex.to_datetime()

    pass_match = %{pass_match | start_time: match_start, end_time: match_end}

    duration = Timex.diff(match_end, match_start, :seconds)

    if duration <= 0 do
      pass_match
    else
      new_plots =
        for plot <- pass_match.plots do
          populate_opts = Keyword.merge(opts, start_time: match_start, end_time: match_end)
          PassPlot.populate_coords(plot, populate_opts)
        end

      %{pass_match | plots: new_plots}
    end
  end
end
