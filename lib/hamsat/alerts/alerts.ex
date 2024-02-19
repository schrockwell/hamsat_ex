defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Accounts
  alias Hamsat.Alerts.Match
  alias Hamsat.Alerts.PassCache
  alias Hamsat.Coord
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.AlertForm
  alias Hamsat.Schemas.Sat
  alias Hamsat.Schemas.SavedAlert
  alias Hamsat.Util

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

      {:error, %Ecto.Changeset{data: %Alert{}} = _alert_changeset} ->
        {:error,
         alert_form_changeset
         |> Map.put(:action, :insert)
         |> add_error(
           :base,
           "Sorry, an internal error occurred. Please take a screenshot and contact WW1X."
         )}
    end
  end

  def update_alert(alert, alert_form_changeset) do
    with {:ok, alert_form} <- Ecto.Changeset.apply_action(alert_form_changeset, :update),
         {:ok, alert} <- Repo.update(Alert.changeset(alert, alert_form)) do
      {:ok, alert}
    else
      {:error, %Ecto.Changeset{data: %AlertForm{}} = alert_form_changeset} ->
        {:error, alert_form_changeset}

      {:error, %Ecto.Changeset{data: %Alert{}} = _alert_changeset} ->
        {:error,
         alert_form_changeset
         |> Map.put(:action, :update)
         |> add_error(
           :base,
           "Sorry, an internal error occurred. Please take a screenshot and contact WW1X."
         )}
    end
  end

  def delete_alert(alert) do
    Repo.delete(alert)
  end

  @doc """
  Lists all upcoming alerts.
  """
  def list_alerts(context, filter \\ [], opts \\ []) do
    alerts =
      filter
      |> Enum.reduce(Alert, &apply_alert_filter(&1, &2, context))
      |> order_by([a], a.aos_at)
      |> Repo.all()
      |> Repo.preload(sat: [:transponders])

    if opts[:for_feed] do
      alerts
      |> amend_visible_passes(context)
    else
      alerts
      |> amend_visible_passes(context)
      |> amend_matches(context)
      |> preload_saved_fields(context)
    end
  end

  @doc """
  Returns an integer count of alerts based on the filter.
  """
  def count_alerts(context, filter \\ []) do
    filter
    |> Enum.reduce(Alert, &apply_alert_filter(&1, &2, context))
    |> Repo.aggregate(:count)
  end

  def get_alert!(context, id) do
    alert =
      Alert
      |> Repo.get!(id)
      |> Repo.preload(sat: [:transponders])

    [alert] =
      [alert]
      |> amend_visible_passes(context)
      |> amend_matches(context)
      |> preload_saved_fields(context)

    alert
  end

  def get_my_alert!(context, id) do
    Alert
    |> user_alert_query(context.user)
    |> Repo.get!(id)
    |> Repo.preload(sat: [:transponders])
  end

  defp user_alert_query(queryable, user) do
    from(a in queryable, where: a.user_id == ^user.id)
  end

  defp apply_alert_filter({:date, :upcoming}, query, _context) do
    where(query, [a], a.los_at >= ^DateTime.utc_now())
  end

  defp apply_alert_filter({:after, datetime}, query, _context) do
    where(query, [a], a.los_at >= ^datetime)
  end

  defp apply_alert_filter({:before, datetime}, query, _context) do
    where(query, [a], a.los_at <= ^datetime)
  end

  defp apply_alert_filter({:date, %Date{} = date}, query, context) do
    bod = date |> Timex.to_datetime(context.timezone) |> Timex.beginning_of_day()
    eod = date |> Timex.to_datetime(context.timezone) |> Timex.end_of_day()

    where(
      query,
      [a],
      (a.aos_at >= ^bod or a.los_at >= ^bod) and (a.aos_at <= ^eod or a.los_at <= ^eod)
    )
  end

  defp apply_alert_filter({:limit, limit}, query, _context) do
    limit(query, ^limit)
  end

  defp apply_alert_filter({:user_id, user_id}, query, _context) do
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

        pass_max_el_at = Util.erl_to_utc_datetime(pass_info.max.datetime)

        max_el =
          cond do
            # Max elevation occurs before AOS
            Timex.compare(pass_max_el_at, alert.aos_at) == -1 ->
              Satellite.Passes.current_position(
                Sat.get_satrec(alert.sat),
                Coord.to_observer(coord),
                Util.utc_datetime_to_erl(alert.aos_at),
                magnitude?: false
              ).elevation_in_degrees

            # Max elevation occurs after LOS
            Timex.compare(pass_max_el_at, alert.los_at) == 1 ->
              Satellite.Passes.current_position(
                Sat.get_satrec(alert.sat),
                Coord.to_observer(coord),
                Util.utc_datetime_to_erl(alert.los_at),
                magnitude?: false
              ).elevation_in_degrees

            # Max elevation occurs during the alert window
            true ->
              pass_info.max.elevation_in_degrees
          end

        %{
          workable_start_at: overlap_start,
          workable_end_at: overlap_end,
          is_workable?: true,
          my_closest_position: my_closest_position,
          activator_closest_position: activator_closest_position,
          max_elevation: max_el
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
      from(sa in SavedAlert,
        where: sa.user_id == ^context.user.id,
        where: sa.alert_id == ^alert.id
      )
    )

    alert
    |> preload_saved_fields(context)
    |> Hamsat.PubSub.broadcast_alert_unsaved(context.user)
  end

  def list_saved_callsigns(alert) do
    callsigns =
      Repo.all(
        from(sa in SavedAlert,
          where: sa.alert_id == ^alert.id,
          join: u in assoc(sa, :user),
          select: u.callsign
        )
      )

    nils = Enum.count(callsigns, &is_nil/1)
    callsigns = callsigns |> Enum.reject(&is_nil/1) |> Enum.sort()
    {callsigns, nils}
  end

  defp preload_saved_fields(%Alert{} = alert, context) do
    [alert] = preload_saved_fields([alert], context)
    alert
  end

  defp preload_saved_fields(alerts, context) when is_list(alerts) do
    alert_ids = Enum.map(alerts, & &1.id)

    counts =
      Repo.all(
        from(sa in SavedAlert,
          where: sa.alert_id in ^alert_ids,
          select: {sa.alert_id, count(sa.id)},
          group_by: sa.alert_id
        )
      )
      |> Map.new()

    my_saved_ids =
      if context.user == :guest do
        MapSet.new()
      else
        Repo.all(
          from(sa in SavedAlert,
            where: sa.alert_id in ^alert_ids,
            where: sa.user_id == ^context.user.id,
            select: sa.alert_id
          )
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
