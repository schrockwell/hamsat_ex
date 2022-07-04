defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Accounts
  alias Hamsat.Alerts.Pass
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
    |> Task.await_many()
    |> List.flatten()
    |> Enum.sort_by(& &1.aos.datetime)
    |> convert_pass_infos_to_passes(context.location)
  end

  defp list_pass_infos(coord, sat, opts) do
    observer = Coord.to_observer(coord)
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

  @doc """
  Creates an alert for a pass.
  """
  def create_alert(context, pass, attrs \\ %{}) do
    context
    |> change_new_alert(pass, attrs)
    |> Repo.insert()
    |> case do
      {:ok, alert} ->
        Accounts.update_alert_preferences!(context.user, alert)
        {:ok, alert}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update_alert(alert, attrs \\ %{}) do
    alert
    |> change_alert(attrs)
    |> Repo.update()
  end

  def delete_alert(alert) do
    Repo.delete(alert)
  end

  @doc """
  Creates an alert changeset for a pass.
  """
  def change_new_alert(context, pass, attrs \\ %{}) do
    Alert.insert_changeset(context, pass, attrs)
  end

  def change_alert(alert, attrs \\ %{}) do
    Alert.update_changeset(alert, attrs)
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

  def get_my_alert!(context, id) do
    Alert
    |> user_alert_query(context.user)
    |> Repo.get!(id)
    |> Repo.preload(:sat)
  end

  defp user_alert_query(queryable, user) do
    from a in queryable, where: a.user_id == ^user.id
  end

  defp apply_alert_filter({:date, :upcoming}, query) do
    where(query, [a], a.los_at >= ^DateTime.utc_now())
  end

  defp apply_alert_filter({:after, datetime}, query) do
    where(query, [a], a.los_at >= ^datetime)
  end

  defp apply_alert_filter({:before, datetime}, query) do
    where(query, [a], a.los_at <= ^datetime)
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

  defp apply_alert_filter({:limit, limit}, query) do
    limit(query, ^limit)
  end

  defp amend_visible_passes(alerts, context) do
    case context.location do
      nil ->
        alerts

      coord ->
        for alert <- alerts do
          Map.merge(alert, visible_attrs(alert, coord))
        end
    end
  end

  defp visible_attrs(alert, coord) do
    satrec = Sat.get_satrec(alert.sat)
    observer = Coord.to_observer(coord)

    case Satellite.Passes.list_passes_until(
           satrec,
           observer,
           Util.utc_datetime_to_erl(alert.aos_at),
           Util.utc_datetime_to_erl(alert.los_at)
         ) do
      [pass_info | _] ->
        pass_aos = Util.erl_to_utc_datetime(pass_info.aos.datetime)
        pass_los = Util.erl_to_utc_datetime(pass_info.los.datetime)

        [_, overlap_start] = Enum.sort([alert.aos_at, pass_aos], DateTime)
        [overlap_end, _] = Enum.sort([alert.los_at, pass_los], DateTime)

        %{workable_start_at: overlap_start, workable_end_at: overlap_end, is_workable?: true}

      [] ->
        %{is_workable?: false}
    end

    # visible_at_aos? =
    #   Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.aos_at)).elevation_in_degrees >
    #     0

    # visible_at_max? =
    #   Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.max_at)).elevation_in_degrees >
    #     0

    # visible_at_los? =
    #   Satellite.Passes.current_position(satrec, observer, Util.utc_datetime_to_erl(alert.los_at)).elevation_in_degrees >
    #     0

    # visible_at_aos? or visible_at_max? or visible_at_los?
  end

  def show_create_alert_button?(context, pass, now) do
    # now < LOS
    Timex.compare(now, pass.info.los.datetime) == -1 and
      (context.user == :guest or context.user.id not in Enum.map(pass.alerts, & &1.user_id))
  end

  def show_edit_alert_button?(context, pass, now) do
    Timex.compare(now, pass.info.los.datetime) == -1 and
      my_alert_during_pass(context, pass) != nil
  end

  def my_alert_during_pass(%{user: :guest}, _pass), do: nil

  def my_alert_during_pass(context, pass) do
    Enum.find(pass.alerts, &(&1.user_id == context.user.id))
  end

  defdelegate mode_options(sat), to: Hamsat.Schemas.Alert
end
