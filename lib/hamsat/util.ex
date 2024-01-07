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
    fields =
      Map.merge(
        %{lat: :lat, lon: :lon, grid: :grid, timezone: :timezone, time_format: :time_format},
        opts[:fields] || %{}
      )

    form
    |> cast(params, [fields.grid, fields.lat, fields.lon, fields.time_format])
    |> validate_number(fields.lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(fields.lon, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> maybe_update_coord_from_grid(fields, opts)
    |> always_update_grid_from_coord(fields)
    |> validate_required([fields.lat, fields.lon])
  end

  # When the grid field changes to a valid value, automatically set new coords
  defp maybe_update_coord_from_grid(changeset, fields, opts) do
    with :coord <- opts[:update],
         new_grid <- get_field(changeset, fields.grid, "AA00"),
         {:ok, {lat, lon}} <- Grid.decode(new_grid) do
      changeset
      |> put_change(fields.lat, lat)
      |> put_change(fields.lon, lon)
    else
      _ -> changeset
    end
  end

  # Always set a new grid based on the coords
  defp always_update_grid_from_coord(changeset, fields) do
    with new_lat <- get_field(changeset, fields.lat, 0),
         new_lon <- get_field(changeset, fields.lon, 0),
         {:ok, new_grid} <- Grid.encode(new_lat, new_lon, 6) do
      put_change(changeset, fields.grid, new_grid)
    else
      _ -> changeset
    end
  end

  def list_timezone_options do
    Tzdata.zone_list()
    |> Enum.map(fn timezone ->
      datetime = DateTime.now!(timezone)
      offset = datetime.utc_offset + datetime.std_offset

      {offset, format_timezone(timezone, offset), timezone}
    end)
    |> Enum.group_by(fn {offset, _, _} -> offset end)
    |> Enum.sort()
    |> Enum.map(fn {offset, options} ->
      options =
        options
        |> Enum.map(fn {_, label, timezone} -> {label, timezone} end)
        |> Enum.sort()

      {format_offset(offset), options}
    end)
  end

  def time_format_options do
    [
      {"12-hour", "12h"},
      {"24-hour", "24h"}
    ]
  end

  defp format_timezone(timezone, offset) do
    timezone = String.replace(timezone, "_", " ")
    "#{timezone} (#{format_offset(offset)})"
  end

  def format_offset(offset) do
    sign = if offset < 0, do: "-", else: "+"

    hours = div(abs(offset), 3600) |> Integer.to_string()
    minutes = div(rem(abs(offset), 3600), 60) |> Integer.to_string() |> String.pad_leading(2, "0")

    "UTC#{sign}#{hours}:#{minutes}"
  end
end
