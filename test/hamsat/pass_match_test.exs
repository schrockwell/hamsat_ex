defmodule Hamsat.PassMatchTest do
  use ExUnit.Case, async: true

  alias Hamsat.Coord
  alias Hamsat.PassMatch
  alias Hamsat.Schemas.Sat

  # ISS TLE from 2026-08-25. With a 51.6° inclination, the ISS never rises
  # above the horizon for an observer at 85°N.
  @tle1 "1 25544U 98067A   26237.53157715  .00007217  00000+0  13603-3 0  9996"
  @tle2 "2 25544  51.6331 316.8722 0007739  83.0953 277.0916 15.49622505582505"

  # A fixed time near the TLE epoch, so pass predictions are deterministic
  @time ~U[2026-08-25 12:00:00Z]

  defp sat do
    %Sat{name: "ISS", number: 25_544, tle: @tle1 <> "\n" <> @tle2}
  end

  test "high-latitude observers get a plot without a pass instead of crashing" do
    polar_viewer = %Coord{lat: 85.0, lon: -45.0}
    activator = %Coord{lat: 40.0, lon: -75.0}

    match = PassMatch.new(sat(), [polar_viewer, activator], @time)

    [viewer_plot, activator_plot] = match.plots

    # The satellite never rises for the polar viewer...
    assert viewer_plot.pass == nil
    assert viewer_plot.coords == []

    # ...but the activator still gets their pass
    assert activator_plot.pass

    # No mutual window exists
    assert match.start_time == nil
    assert match.end_time == nil
  end

  test "two mid-latitude observers get a mutual pass window" do
    obs1 = %Coord{lat: 41.5, lon: -73.0}
    obs2 = %Coord{lat: 40.0, lon: -75.0}

    match = PassMatch.new(sat(), [obs1, obs2], @time)

    assert Enum.all?(match.plots, & &1.pass)
    assert %DateTime{} = match.start_time
    assert %DateTime{} = match.end_time
  end
end
