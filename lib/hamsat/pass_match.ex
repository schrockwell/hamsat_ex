defmodule Hamsat.PassMatch do
  defstruct [:sat, :plots, :start_time, :end_time]

  defmodule PassPlot do
    defstruct [:location, :pass, coords: []]
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
    pass = Satellite.next_pass(satrec, Timex.to_erl(time), observer)

    %PassPlot{location: location, pass: pass}
  end

  defp populate_coords(pass_match, opts) do
    points = opts[:points] || 40

    satrec = Sat.get_satrec(pass_match.sat)

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
    step = duration / points

    if duration <= 0 do
      pass_match
    else
      new_plots =
        for plot <- pass_match.plots do
          observer = Coord.to_observer(plot.location)

          coords =
            Enum.map(0..points, fn i ->
              time = Timex.shift(match_start, seconds: trunc(i * step))
              pos = Satellite.Passes.current_position(satrec, observer, Timex.to_erl(time))
              %{az: pos.azimuth_in_degrees, el: pos.elevation_in_degrees}
            end)

          %{plot | coords: coords}
        end

      %{pass_match | plots: new_plots}
    end
  end
end
