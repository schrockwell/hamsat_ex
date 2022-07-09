defmodule Hamsat.Util do
  import Ecto.Changeset

  alias Hamsat.Grid

  def erl_to_utc_datetime(erl_datetime) do
    erl_datetime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end

  def utc_datetime_to_erl(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
  end

  def location_picker_changeset(form, params \\ %{}, opts \\ []) do
    fields = Map.merge(%{lat: :lat, lon: :lon, grid: :grid}, opts[:fields] || %{})

    form
    |> cast(params, [fields.grid, fields.lat, fields.lon])
    |> validate_number(fields.lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(fields.lon, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> maybe_update_coord_from_grid(fields)
    |> maybe_update_grid_from_coord(fields)
    |> validate_required([fields.lat, fields.lon])
    |> Map.put(:action, :update)
  end

  # When the grid field changes to a valid value, automatically set new coords
  defp maybe_update_coord_from_grid(changeset, fields) do
    with {:ok, new_grid} <- fetch_change(changeset, fields.grid),
         {:ok, {lat, lon}} <- Grid.decode(new_grid) do
      changeset
      |> force_change(fields.lat, lat)
      |> force_change(fields.lon, lon)
    else
      _ -> changeset
    end
  end

  # When the coord fields change, automatically set a new grid
  defp maybe_update_grid_from_coord(changeset, fields) do
    new_lat = get_field(changeset, fields.lat, 0)
    new_lon = get_field(changeset, fields.lon, 0)

    case Grid.encode(new_lat, new_lon, 6) do
      {:ok, new_grid} ->
        force_change(changeset, fields.grid, new_grid)

      :error ->
        changeset
    end
  end
end
