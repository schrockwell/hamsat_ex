defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Changeset
  alias Hamsat.Accounts
  alias Hamsat.Alerts.Match
  alias Hamsat.Alerts.Pass
  alias Hamsat.Alerts.PassCache
  alias Hamsat.Context
  alias Hamsat.Coord
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.AlertForm
  alias Hamsat.Schemas.Sat
  alias Hamsat.Schemas.SavedAlert
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

  def change_alert(context, sat, pass, params) do
    AlertForm.changeset(context, sat, pass, params)
  end

  @doc """
  Creates an alert for a pass.
  """
  def create_alert(context, alert_form_changeset) do
    with {:ok, alert_form} <- Ecto.Changeset.apply_action(alert_form_changeset, :create),
         {:ok, alert} <- Repo.insert(Alert.changeset(%Alert{}, alert_form)) do
      Accounts.update_alert_preferences!(context.user, alert)
      {:ok, alert}
    else
      {:error, %Ecto.Changeset{data: %AlertForm{}} = alert_form_changeset} ->
        {:error, alert_form_changeset}

      {:error, %Ecto.Changeset{data: %Alert{}} = alert_changeset} ->
        {:error,
         alert_form_changeset
         |> Map.put(:action, :insert)
         |> add_error(:base, "Sorry, an internal error occurred. Please take a screenshot and contact WW1X.")}
    end
  end

  def update_alert(alert, context, alert_form_changeset) do
    with {:ok, alert_form} <- Ecto.Changeset.apply_action(alert_form_changeset, :update),
         {:ok, alert} <- Repo.update(Alert.changeset(alert, alert_form)) do
      {:ok, alert}
    else
      {:error, %Ecto.Changeset{data: %AlertForm{}} = alert_form_changeset} ->
        {:error, alert_form_changeset}

      {:error, %Ecto.Changeset{data: %Alert{}} = alert_changeset} ->
        {:error,
         alert_form_changeset
         |> Map.put(:action, :update)
         |> add_error(:base, "Sorry, an internal error occurred. Please take a screenshot and contact WW1X.")}
    end
  end

  def delete_alert(alert) do
    Repo.delete(alert)
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
    |> amend_matches(context)
    |> preload_saved_fields(context)
  end

  @doc """
  Returns an integer count of alerts based on the filter.
  """
  def count_alerts(filter \\ []) do
    filter
    |> Enum.reduce(Alert, &apply_alert_filter/2)
    |> Repo.aggregate(:count)
  end

  def get_alert!(context, id) do
    alert =
      Alert
      |> Repo.get!(id)
      |> Repo.preload(:sat)

    [alert] =
      [alert]
      |> amend_visible_passes(context)
      |> amend_matches(context)

    alert
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

  defp apply_alert_filter({:user_id, user_id}, query) do
    where(query, [a], a.user_id == ^user_id)
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
    case PassCache.list_passes_until(alert.sat, coord, alert.aos_at, alert.los_at) do
      [pass_info | _] ->
        pass_aos = Util.erl_to_utc_datetime(pass_info.aos.datetime)
        pass_los = Util.erl_to_utc_datetime(pass_info.los.datetime)

        {my_closest_position, activator_closest_position} = closest_position(alert, coord)

        [_, overlap_start] = Enum.sort([alert.aos_at, pass_aos], DateTime)
        [overlap_end, _] = Enum.sort([alert.los_at, pass_los], DateTime)

        %{
          workable_start_at: overlap_start,
          workable_end_at: overlap_end,
          is_workable?: true,
          my_closest_position: my_closest_position,
          activator_closest_position: activator_closest_position
        }

      [] ->
        %{is_workable?: false}
    end
  end

  defp closest_position(alert, coord) do
    satrec = Sat.get_satrec(alert.sat)
    obs1 = coord |> Coord.to_observer()
    obs2 = alert |> Alert.observer_coord() |> Coord.to_observer()

    iterate_closest_position(satrec, obs1, obs2, alert.aos_at, alert.los_at, :infinity)
  end

  defp iterate_closest_position(satrec, obs1, obs2, datetime, los_at, min_range) do
    erl_datetime = Util.utc_datetime_to_erl(datetime)

    pos1 =
      Satellite.Passes.current_position(satrec, obs1, erl_datetime,
        magnitude?: false,
        geodetic?: false
      )

    pos2 =
      Satellite.Passes.current_position(satrec, obs2, erl_datetime,
        magnitude?: false,
        geodetic?: false
      )

    total_range = pos1.range + pos2.range

    cond do
      # Alert LOS, so if we made it this far, it's actually the closest approach
      DateTime.compare(datetime, los_at) == :gt ->
        {pos1, pos2}

      # New minimum!
      total_range < min_range or min_range == :infinity ->
        iterate_closest_position(
          satrec,
          obs1,
          obs2,
          DateTime.add(datetime, 5),
          los_at,
          total_range
        )

      # The range increased, so we're not longer at the minimum, so we must be done
      true ->
        {pos1, pos2}
    end
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

  def save_alert(context, alert) do
    context.user
    |> SavedAlert.changeset(alert)
    |> Repo.insert()

    alert
    |> preload_saved_fields(context)
    |> Hamsat.PubSub.broadcast_alert_saved(context.user)
  end

  def unsave_alert(context, alert) do
    Repo.delete_all(
      from sa in SavedAlert,
        where: sa.user_id == ^context.user.id,
        where: sa.alert_id == ^alert.id
    )

    alert
    |> preload_saved_fields(context)
    |> Hamsat.PubSub.broadcast_alert_unsaved(context.user)
  end

  defp preload_saved_fields(%Alert{} = alert, context) do
    [alert] = preload_saved_fields([alert], context)
    alert
  end

  defp preload_saved_fields(alerts, context) when is_list(alerts) do
    alert_ids = Enum.map(alerts, & &1.id)

    counts =
      Repo.all(
        from sa in SavedAlert,
          where: sa.alert_id in ^alert_ids,
          select: {sa.alert_id, count(sa.id)},
          group_by: sa.alert_id
      )
      |> Map.new()

    my_saved_ids =
      if context.user == :guest do
        MapSet.new()
      else
        Repo.all(
          from sa in SavedAlert,
            where: sa.alert_id in ^alert_ids,
            where: sa.user_id == ^context.user.id,
            select: sa.alert_id
        )
        |> MapSet.new()
      end

    for alert <- alerts do
      %{
        alert
        | saved_count: Map.get(counts, alert.id, 0),
          saved?: MapSet.member?(my_saved_ids, alert.id)
      }
    end
  end

  def patch_alerts(
        alerts,
        context,
        {:alert_saved, %{alert_id: alert_id, user_id: user_id, saved_count: saved_count}}
      ) do
    context_user_id = if context.user == :guest, do: nil, else: context.user.id

    Enum.map(alerts, fn
      %{id: ^alert_id} = alert ->
        %{alert | saved_count: saved_count, saved?: user_id == context_user_id}

      alert ->
        alert
    end)
  end

  def patch_alerts(
        alerts,
        context,
        {:alert_unsaved, %{alert_id: alert_id, user_id: user_id, saved_count: saved_count}}
      ) do
    context_user_id = if context.user == :guest, do: nil, else: context.user.id

    Enum.map(alerts, fn
      %{id: ^alert_id} = alert ->
        %{
          alert
          | saved_count: saved_count,
            saved?: user_id != context_user_id
        }

      alert ->
        alert
    end)
  end

  defp amend_matches(alerts, context) do
    for alert <- alerts, do: Match.amend_alert(alert, context)
  end
end
