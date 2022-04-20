defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Alerts.Pass
  alias Hamsat.Context
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat
  alias Hamsat.Util

  @doc """
  Returns a sorted list of satellite passes for one satellite.
  """
  def list_passes(context, sat, opts \\ []) do
    context
    |> list_pass_infos(sat, opts)
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes()
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
    |> convert_pass_infos_to_passes()
  end

  defp list_pass_infos(context, sat, opts) do
    observer = Context.get_observer(context)
    satrec = Sat.get_satrec(sat)
    count = opts[:count] || 1

    Satellite.list_passes(satrec, count, observer, :calendar.universal_time())
  end

  defp convert_pass_infos_to_passes(infos) do
    sat_numbers = infos |> Enum.map(& &1.satnum) |> Enum.uniq()

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
        sat: sat
      }
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
  def list_upcoming_alerts(context) do
    from(a in Alert,
      where: a.los_at > ^DateTime.utc_now(),
      order_by: a.aos
    )
    |> Repo.all()
    |> Repo.preload([:sat])
    |> amend_visible_passes(context)
  end

  defp amend_visible_passes(alerts, context) do
    case Context.get_observer(context) do
      nil ->
        alerts

      observer ->
        for alert <- alerts do
          %{alert | is_visible?: is_visible_during_alert?(alert, observer)}
        end
    end
  end

  defp is_visible_during_alert?(alert, observer) do
    satrec = Sat.get_satrec(alert.sat)

    visible_at_aos? =
      Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.aos_at)).elevation_degrees >
        0

    visible_at_los? =
      Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.los_at)).elevation_degrees >
        0

    visible_at_aos? or visible_at_los?
  end
end
