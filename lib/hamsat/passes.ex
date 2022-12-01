defmodule Hamsat.Passes do
  use Hamsat, :repo

  alias Hamsat.Alerts.Pass
  alias Hamsat.Alerts.PassCache
  alias Hamsat.Context
  alias Hamsat.Coord
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat
  alias Hamsat.Util

  def get_pass_by_hash(context, hash) do
    hash = Pass.decode_hash!(hash)
    sat = Hamsat.Satellites.get_satellite_by_number!(hash.satnum)
    max_datetime = Timex.to_datetime(hash.max_datetime_erl)
    # observer = Observer.create_from(hash.lat, hash.lon)

    [pass] = list_passes(context, sat, starting: max_datetime, ending: max_datetime)
    pass
  end

  def get_pass_by_alert(alert) do
    coord = %Coord{lat: alert.observer_lat, lon: alert.observer_lon}
    [pass] = list_passes(coord, alert.sat, starting: alert.max_at, ending: alert.max_at)
    pass
  end

  @doc """
  Returns a sorted list of satellite passes for one satellite.
  """
  def list_passes(context, sat, opts \\ [])

  def list_passes(%Context{} = context, sat, opts) do
    list_passes(context.location, sat, opts)
  end

  def list_passes(%Coord{} = coord, sat, opts) do
    coord
    |> list_pass_infos(sat, opts)
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes(coord)
  end

  @doc """
  Returns a sorted list of satellite passes for many satellites.
  """
  def list_all_passes(context, sats, opts \\ []) do
    sats
    |> Enum.map(fn sat ->
      Task.async(fn ->
        list_pass_infos(context.location, sat, opts)
      end)
    end)
    |> Task.await_many(30_000)
    |> List.flatten()
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes(context.location)
  end

  defp list_pass_infos(coord, sat, opts) do
    starting = opts[:starting] || DateTime.utc_now()
    ending = opts[:ending] || Timex.shift(starting, hours: 6)

    PassCache.list_passes_until(sat, coord, starting, ending)
  end

  defp convert_pass_infos_to_passes(infos, coord) do
    sat_numbers = infos |> Enum.map(& &1.satnum) |> Enum.uniq()
    observer = Coord.to_observer(coord)

    sats =
      from(s in Sat, where: s.number in ^sat_numbers)
      |> Repo.all()
      |> Enum.group_by(& &1.number)

    sat_alerts =
      from(a in Alert,
        join: s in assoc(a, :sat),
        where: s.number in ^sat_numbers
      )
      |> Repo.all()
      |> Repo.preload([:sat])
      |> Enum.group_by(& &1.sat.number)

    for info <- infos do
      info_aos = Util.erl_to_utc_datetime(info.aos.datetime)
      info_los = Util.erl_to_utc_datetime(info.los.datetime)

      alerts =
        sat_alerts
        |> Map.get(info.satnum, [])
        |> Enum.filter(fn alert ->
          # If datetime rangers overlap
          DateTime.compare(alert.aos_at, info_los) in [:lt, :eq] and
            DateTime.compare(alert.los_at, info_aos) in [:gt, :eq]
        end)
        |> Enum.sort_by(& &1.callsign)

      sat =
        case Map.get(sats, info.satnum, []) do
          [s] -> s
          [] -> nil
        end

      %Pass{
        id: Ecto.UUID.generate(),
        info: info,
        alerts: alerts,
        sat: sat,
        observer: observer
      }
      |> Pass.put_hash()
    end
  end
end
