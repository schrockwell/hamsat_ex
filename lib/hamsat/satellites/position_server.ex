defmodule Hamsat.Satellites.PositionServer do
  use GenServer

  alias Hamsat.Coord
  alias Hamsat.Satellites
  alias Hamsat.Schemas.Sat

  # Don't care about the observer, just need it for the satellite position calculation
  @observer Coord.to_observer(%Coord{lat: 0, lon: 0})
  @tick_interval 1_000

  def start_link(_) do
    sats = Satellites.list_satellites()
    GenServer.start_link(__MODULE__, sats, name: __MODULE__)
  end

  def get_sat_positions() do
    GenServer.call(__MODULE__, :get_sat_positions)
  end

  def init(sats) do
    {:ok, %{sats: sats, sat_positions: %{}}, {:continue, []}}
  end

  def handle_continue(_, state) do
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, update_sat_positions(state)}
  end

  def handle_info(:tick, state) do
    Process.send_after(self(), :tick, @tick_interval)
    {:noreply, update_sat_positions(state)}
  end

  def handle_call(:get_sat_positions, _from, state) do
    {:reply, state.sat_positions, state}
  end

  defp update_sat_positions(state) do
    positions =
      state.sats
      |> Enum.map(&sat_position/1)
      |> Enum.reject(&is_nil/1)
      |> Hamsat.PubSub.broadcast_satellite_positions()

    %{state | sat_positions: positions}
  end

  defp sat_position(sat) do
    if satrec = Sat.get_satrec(sat) do
      %{sat_id: sat.id, position: Satellite.current_position(satrec, @observer, magnitude?: false)}
    end
  end
end
