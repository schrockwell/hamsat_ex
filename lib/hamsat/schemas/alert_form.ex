defmodule Hamsat.Schemas.AlertForm do
  use Hamsat, :schema

  import Hamsat.Changeset

  alias Hamsat.Context
  alias Hamsat.Grid
  alias Hamsat.Alerts.Pass
  alias Hamsat.Modulation
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  # @grid_fields [:grid_1, :grid_2, :grid_3, :grid_4]

  embedded_schema do
    # Pass selection
    belongs_to :sat, Sat, foreign_key: :satellite_id
    field :pass_filter_date, :date
    field :pass_hash, :string
    field :observer_lat, :float
    field :observer_lon, :float

    # Alert info
    field :grid_1, :string
    field :grid_2, :string
    field :grid_3, :string
    field :grid_4, :string
    field :mhz, :float
    field :mhz_direction, Ecto.Enum, values: [:up, :down]
    field :mode, :string
    field :callsign, :string
    field :comment, :string
  end

  def initial_params(%Context{} = context, %Sat{} = sat) do
    %{
      # Pass selection
      "satellite_id" => sat.id,
      "pass_filter_date" => Date.utc_today(),
      "observer_lat" => context.location.lat,
      "observer_lon" => context.location.lon,

      # Alert info
      "callsign" => context.user.latest_callsign,
      "mhz_direction" => preferred_mhz_direction(context.user),
      "mode" => preferred_mode(context.user, sat)
    }
  end

  def initial_params(%Context{} = context, %Pass{} = pass) do
    context
    |> initial_params(pass.sat)
    |> Map.merge(%{
      "pass_hash" => pass.hash,
      "pass_filter_date" => Timex.to_date(pass.info.max.datetime),
      "observer_lat" => pass.observer.latitude_deg,
      "observer_lon" => pass.observer.longitude_deg
    })
  end

  def from_alert(%Alert{} = alert) do
    %__MODULE__{
      satellite_id: alert.satellite_id,
      sat: alert.sat,
      pass_filter_date: DateTime.to_date(alert.max_at),
      # TODO: grids
      grid_1: Grid.encode!({alert.observer_lat, alert.observer_lon}, 6),
      grid_2: nil,
      grid_3: nil,
      grid_4: nil,
      mhz: alert.mhz,
      mhz_direction: alert.mhz_direction,
      mode: alert.mode,
      callsign: alert.callsign,
      comment: alert.comment
    }
  end

  def changeset(%__MODULE__{} = form, params \\ %{}) do
    form
    |> cast(params, [
      :callsign,
      :comment,
      :grid_1,
      :grid_2,
      :grid_3,
      :grid_4,
      :mhz_direction,
      :mhz,
      :mode,
      :pass_filter_date,
      :pass_hash,
      :satellite_id,
      :observer_lat,
      :observer_lon
    ])
    |> format_callsign()
    |> validate_required([:callsign])
    # |> validate_grids()
    # |> put_forced_mhz()
    |> validate_length(:callsign, min: 3)
    |> validate_length(:comment, max: 50)
  end

  defp preferred_mode(user, sat) do
    case Modulation.alert_options(sat) do
      [mode] ->
        mode

      sat_modes ->
        # The list of latest_modes is ordered by most-recent, so try to find the first one
        # that is applicable to this satellite
        Enum.find(user.latest_modes, hd(sat_modes), fn mode ->
          mode in sat_modes
        end)
    end
  end

  defp preferred_mhz_direction(user), do: user.latest_mhz_direction || :down

  @doc """
  Returns a list one, two, or four grids that are nearby the given observer coordinate.
  """
  def recommended_grids(%Ecto.Changeset{} = changeset) do
    lat = get_field(changeset, :observer_lat)
    lon = get_field(changeset, :observer_lon)
    recommended_grids(lat, lon)
  end

  def recommended_grids(lat, lon) do
    all_grids =
      for delta_lat <- [-1.0, 0, 1.0], delta_lon <- [-2.0, 0, 2.0] do
        Grid.encode!(lat + delta_lat, lon + delta_lon, 4)
      end

    Enum.filter(all_grids, fn grid ->
      {:ok, {grid_center_lat, grid_center_lon}} = Grid.decode(grid)

      # Warning: does not account for longitude wrapping from -180 to +180
      slop = 0.05
      within_lat? = abs(grid_center_lat - lat) < 0.50 + slop
      within_lon? = abs(grid_center_lon - lon) < 1.00 + slop

      within_lat? and within_lon?
    end)
  end

  # defp validate_grids(changeset) do
  #   cond do
  #     Enum.all?(@grid_fields, fn field -> get_field(changeset, field) == nil end) ->
  #       add_error(changeset, :grid_1, "is required")
  #   end
  # end

  # def decode_adjacent_grids([]), do: {:error, :invalid}

  # def decode_adjacent_grids(grids) do
  #   grid_coords =
  #     grids
  #     |> Enum.reject(&is_nil/1)
  #     |> Enum.map(&Grid.decode/1)

  #   if Enum.any?(grid_coords, &(&1 == :error)) do
  #     {:error, :invalid}
  #   else
  #     grid_coords = Enum.map(grid_coords, fn {:ok, coord} -> coord end)

  #     # This doesn't take -180 and +180 longitude into account
  #     {min_lat, max_lat} = grid_coords |> Enum.map(fn {lat, _lon} -> lat end) |> Enum.min_max()
  #     {min_lon, max_lon} = grid_coords |> Enum.map(fn {_lat, lon} -> lon end) |> Enum.min_max()

  #     if max_lat - min_lat > 1.0 or max_lon - min_lon > 2.0 do
  #       {:error, :not_adjacent}
  #     else
  #       {:ok, {(max_lat + min_lat) / 2.0, (max_lon + min_lon) / 2.0}}
  #     end
  #   end
  # end
end
