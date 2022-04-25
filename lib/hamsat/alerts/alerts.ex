defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Alerts.Pass
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

  @doc """
  Returns a sorted list of satellite passes for one satellite.
  """
  def list_passes(context, sat, opts \\ []) do
    context
    |> list_pass_infos(sat, opts)
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes(context)
  end

  @doc """
  Returns a sorted list of satellite passes for many satellites.
  """
  def list_all_passes(context, sats, opts \\ []) do
    sats
    |> Enum.map(fn sat ->
      Task.async(fn ->
        list_pass_infos(context, sat, opts)
      end)
    end)
    |> Task.await_many()
    |> List.flatten()
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes(context)
  end

  defp list_pass_infos(context, sat, opts) do
    observer = Coord.to_observer(context.location)
    satrec = Sat.get_satrec(sat)
    starting = opts[:starting] || DateTime.utc_now()
    ending = opts[:ending] || Timex.shift(starting, hours: 6)

    Satellite.list_passes_until(
      satrec,
      observer,
      Util.utc_datetime_to_erl(starting),
      Util.utc_datetime_to_erl(ending)
    )
  end

  defp convert_pass_infos_to_passes(infos, context) do
    sat_numbers = infos |> Enum.map(& &1.satnum) |> Enum.uniq()
    observer = Coord.to_observer(context.location)

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

  @doc """
  Creates an alert for a pass.
  """
  def create_alert(context, pass, attrs \\ %{}) do
    context
    |> Alert.insert_changeset(pass, attrs)
    |> Repo.insert()
  end

  @doc """
  Lists all upcoming alerts.
  """
  def list_alerts(context, filter \\ []) do
    filter
    |> Enum.reduce(Alert, &apply_alert_filter/2)
    |> order_by([a], a.aos_at)
    |> Repo.all()
    |> Repo.preload([:sat])
    |> amend_visible_passes(context)
  end

  defp apply_alert_filter({:date, :upcoming}, query) do
    where(query, [a], a.aos_at >= ^DateTime.utc_now())
  end

  defp apply_alert_filter({:date, %Date{} = date}, query) do
    bod = date |> Timex.to_datetime() |> Timex.beginning_of_day()
    eod = date |> Timex.to_datetime() |> Timex.end_of_day()

    where(
      query,
      [a],
      (a.aos_at >= ^bod or a.los_at >= ^bod) and (a.aos_at <= ^eod or a.los_at <= ^eod)
    )
  end

  defp amend_visible_passes(alerts, context) do
    case context.location do
      nil ->
        alerts

      coord ->
        for alert <- alerts do
          %{alert | is_visible?: is_visible_during_alert?(alert, coord)}
        end
    end
  end

  defp is_visible_during_alert?(alert, coord) do
    satrec = Sat.get_satrec(alert.sat)
    observer = Coord.to_observer(coord)

    visible_at_aos? =
      Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.aos_at)).elevation_in_degrees >
        0

    visible_at_los? =
      Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.los_at)).elevation_in_degrees >
        0

    visible_at_aos? or visible_at_los?
  end

  def can_create_alert_for?(pass, at: now) do
    # now < LOS
    Timex.compare(now, pass.info.los.datetime) == -1
  end
end
