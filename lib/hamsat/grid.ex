defmodule Hamsat.Grid do
  @moduledoc false

  alias Hamsat.Coord

  @alphabet ~w(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z)
  @regex ~r/[A-R]{2}[0-9]{2}($|([a-x]{2}$))/i

  def encode({lat, lon}, length), do: encode(lat, lon, length)
  def encode(%Coord{lat: lat, lon: lon}, length), do: encode(lat, lon, length)

  def encode(lat, lon, length)
      when length in [4, 6] and lat >= -90.0 and lat <= 90 and lon >= -180 and lon <= 180 do
    # Normalize from (-90, -180) to (0, 0)
    lon = lon + 180.0
    lat = lat + 90.0

    # Map lon from 0 to 17 (A to R)
    lon_index_1 = trunc(lon / 20.0)
    lat_index_1 = trunc(lat / 10.0)

    # 20 degrees lon per grid
    lon = lon - lon_index_1 * 20.0
    # 10 degrees lat per grid
    lat = lat - lat_index_1 * 10.0

    # Map from 0 to 9
    lon_index_2 = trunc(lon / 2.0)
    lat_index_2 = trunc(lat)

    # Convert to string
    grid =
      "#{Enum.at(@alphabet, lon_index_1)}#{Enum.at(@alphabet, lat_index_1)}#{lon_index_2}#{lat_index_2}"

    if length == 6 do
      # Now 2 degrees lon per grid remaining
      lon = lon - lon_index_2 * 2.0
      # Now 1 degree lon per grid remaining
      lat = lat - lat_index_2

      # Map from 0 to 23 (a to x)
      lon_index_3 = trunc(lon / (2.0 / 24.0))
      lat_index_3 = trunc(lat / (1.0 / 24.0))

      # Return 6-letter grid
      {
        :ok,
        "#{grid}#{String.downcase(Enum.at(@alphabet, lon_index_3))}#{String.downcase(Enum.at(@alphabet, lat_index_3))}"
      }
    else
      # Return 4-letter grid
      {:ok, grid}
    end
  end

  def encode(_, _, _), do: :error

  def encode!({lat, lon}, length), do: encode!(lat, lon, length)
  def encode!(%Coord{lat: lat, lon: lon}, length), do: encode!(lat, lon, length)

  def encode!(lat, lon, length) do
    {:ok, grid} = encode(lat, lon, length)
    grid
  end

  def decode(grid) when is_binary(grid) do
    if valid?(grid) do
      decode_valid(grid)
    else
      :error
    end
  end

  def decode(_), do: :error

  def valid?(grid) do
    Regex.match?(@regex, grid)
  end

  def format(grid) do
    {a, b} = String.split_at(grid, 2)
    String.upcase(a) <> b
  end

  # PRIVATE

  defp decode_valid(grid) do
    lon = -180.0
    lat = -90.0

    lon_ord_1 =
      Enum.find_index(@alphabet, fn letter -> String.upcase(String.at(grid, 0)) == letter end)

    lat_ord_1 =
      Enum.find_index(@alphabet, fn letter -> String.upcase(String.at(grid, 1)) == letter end)

    lon_ord_2 = String.at(grid, 2) |> String.to_integer()
    lat_ord_2 = String.at(grid, 3) |> String.to_integer()

    lon = lon + 360.0 / 18.0 * lon_ord_1 + 360.0 / 18.0 / 10.0 * lon_ord_2
    lat = lat + 180.0 / 18.0 * lat_ord_1 + 180.0 / 18.0 / 10.0 * lat_ord_2

    case String.length(grid) do
      4 ->
        lon = lon + 360.0 / 18.0 / 10.0 / 2.0
        lat = lat + 180.0 / 18.0 / 10.0 / 2.0

        {:ok, {lat, lon}}

      6 ->
        lon_ord_3 =
          Enum.find_index(@alphabet, fn letter -> String.upcase(String.at(grid, 4)) == letter end)

        lat_ord_3 =
          Enum.find_index(@alphabet, fn letter -> String.upcase(String.at(grid, 5)) == letter end)

        lon = lon + 360.0 / 18.0 / 10.0 / 24.0 * (lon_ord_3 + 0.5)
        lat = lat + 180.0 / 18.0 / 10.0 / 24.0 * (lat_ord_3 + 0.5)

        {:ok, {lat, lon}}

      _ ->
        :error
    end
  end
end
