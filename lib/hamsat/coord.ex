defmodule Hamsat.Coord do
  defstruct [:lat, :lon]

  def to_observer(%__MODULE__{} = coord) do
    Observer.create_from(coord.lat, coord.lon, 0)
  end
end
