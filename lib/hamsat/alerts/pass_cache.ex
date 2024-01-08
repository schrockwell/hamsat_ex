defmodule Hamsat.Alerts.PassCache do
  @moduledoc """
  Stores satellite passes in ETS after they have been calculated.
  """
  require Logger

  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.Schemas.Sat
  alias Hamsat.Util

  defmodule Bucket do
    defstruct [:key, :starting, :ending]
  end

  @hours_per_bucket 6
  @table __MODULE__
  @max_age_ms :timer.hms(24, 0, 0)

  def initialize do
    :ets.new(@table, [:public, :set, :named_table])
  end

  def purge do
    cutoff = System.monotonic_time(:millisecond) - @max_age_ms

    # :ets.fun2ms(fn {_, inserted_at, _} -> inserted_at < 123 end)
    match_spec = [{{:_, :"$1", :_}, [], [{:<, :"$1", cutoff}]}]

    :ets.select_delete(@table, match_spec)
  end

  def purge_all do
    :ets.delete_all_objects(@table)
  end

  def list_passes_until(
        %Sat{} = sat,
        %Coord{} = coord,
        %DateTime{} = starting,
        %DateTime{} = ending
      ) do
    sat
    |> buckets(coord, starting, ending)
    |> Task.async_stream(
      fn bucket ->
        get_or_calculate_passes(sat, coord, bucket)
      end,
      timeout: 60_000
    )
    |> Enum.flat_map(fn
      {:ok, passes} -> passes
      _ -> []
    end)
    # We fetched a bunch of passes within big 6-hour buckets, so filter out based on the actual
    # requested datetime range
    |> Enum.filter(fn pass ->
      DateTime.compare(Util.erl_to_utc_datetime(pass.los.datetime), starting) in [:gt, :eq] and
        DateTime.compare(Util.erl_to_utc_datetime(pass.aos.datetime), ending) in [:lt, :eq]
    end)
    # There's a pretty good chance of dupes because Satellite.list_passes_until/4 will return passes
    # AFTER the bucket end time
    |> Enum.uniq_by(&{&1.satnum, &1.start_time})
  end

  defp buckets(sat, coord, starting, ending, acc \\ [])

  defp buckets(sat, coord, starting, ending, acc) do
    if DateTime.compare(starting, ending) == :gt do
      Enum.reverse(acc)
    else
      bucket_starting_hour = floor(starting.hour / @hours_per_bucket) * @hours_per_bucket

      bucket_starting = %{
        starting
        | hour: bucket_starting_hour,
          minute: 0,
          second: 0,
          microsecond: {0, 0}
      }

      bucket_ending = Timex.shift(bucket_starting, hours: 6)

      new_bucket = %Bucket{
        key: bucket_key(sat, coord, bucket_starting),
        starting: bucket_starting,
        ending: bucket_ending
      }

      new_starting = Timex.shift(bucket_starting, hours: @hours_per_bucket)
      buckets(sat, coord, new_starting, ending, [new_bucket | acc])
    end
  end

  defp bucket_key(sat, coord, datetime) do
    ymd = Timex.format!(datetime, "{YYYY}-{0M}-{0D}")
    hour = floor(datetime.hour / @hours_per_bucket)
    grid = Grid.encode!(coord, 6)

    "#{ymd}:#{hour}:#{grid}:#{sat.number}"
  end

  defp get_or_calculate_passes(sat, coord, bucket) do
    # When a sat burns up, it is no longer in the AMSAT TLEs
    if satrec = Sat.get_satrec(sat) do
      case :ets.lookup(@table, bucket.key) do
        [] ->
          Logger.debug("PassCache MISS for #{bucket.key}")
          passes = try_list_passes(satrec, coord, bucket)
          :ets.insert(@table, {bucket.key, System.monotonic_time(:millisecond), passes})
          passes

        [{_key, _inserted_at, cached_passes}] ->
          Logger.debug("PassCache HIT for #{bucket.key}")
          cached_passes
      end
    else
      []
    end
  end

  defp try_list_passes(satrec, coord, bucket) do
    try do
      Satellite.list_passes_until(
        satrec,
        Coord.to_observer(coord),
        Util.utc_datetime_to_erl(bucket.starting),
        Util.utc_datetime_to_erl(bucket.ending),
        # These are the pass_opts that I added to satellite_ex to improve the performance
        # of these pass calculations
        magnitude?: false,
        geodetic?: false,
        coarse_increment: 60,
        fine_increment: 5
      )
    rescue
      error ->
        Logger.warn("Error listing passes for bucket #{bucket.key}: #{error.message}")
        []
    end
  end
end
