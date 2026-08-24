defmodule Hamsat.Alerts.ReminderNotifier do
  @moduledoc """
  Sends a browser push notification to users who liked an activation, one
  minute before it begins.

  Sweeps every few seconds for liked alerts whose AOS is within the reminder
  lead time. Each like is marked `notified_at` before sending so a reminder is
  pushed at most once, and expired subscriptions are pruned as push services
  report them gone.
  """

  use GenServer

  import Ecto.Query

  require Logger

  alias Hamsat.Accounts.PushSubscription
  alias Hamsat.Push.WebPush
  alias Hamsat.Repo
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.SavedAlert

  @sweep_interval :timer.seconds(10)
  @lead_time_seconds 60

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval)
  end

  @doc """
  Finds due reminders, marks them notified, and pushes them. Public so it can
  be exercised directly.
  """
  def sweep(now \\ DateTime.utc_now()) do
    for {saved_alert_id, user_id, alert_id} <- due_reminders(now) do
      # Claim before sending so a crash mid-send cannot double-notify
      {claimed, _} =
        Repo.update_all(
          from(sa in SavedAlert, where: sa.id == ^saved_alert_id and is_nil(sa.notified_at)),
          set: [notified_at: DateTime.truncate(now, :second)]
        )

      if claimed == 1 do
        push_reminder(user_id, alert_id)
      end
    end

    :ok
  end

  # Likes of upcoming alerts rising within the lead time, by users who opted in.
  # Alerts already begun are included (sweep granularity), but passed ones aren't.
  defp due_reminders(now) do
    lead = DateTime.add(now, @lead_time_seconds, :second)

    Repo.all(
      from sa in SavedAlert,
        join: a in Alert,
        on: a.id == sa.alert_id,
        join: u in assoc(sa, :user),
        where: is_nil(sa.notified_at),
        where: u.push_reminders_enabled,
        where: a.aos_at <= ^lead and a.los_at > ^now,
        select: {sa.id, sa.user_id, sa.alert_id}
    )
  end

  defp push_reminder(user_id, alert_id) do
    alert = Repo.get!(Alert, alert_id) |> Repo.preload(:sat)

    payload =
      Jason.encode!(%{
        title: "#{alert.callsign} on #{alert.sat.name}",
        body: "This activation begins in about a minute.",
        url: "/alerts/#{alert.id}"
      })

    subscriptions = Repo.all(from ps in PushSubscription, where: ps.user_id == ^user_id)

    for subscription <- subscriptions do
      case WebPush.send_notification(PushSubscription.to_web_push(subscription), payload) do
        {:ok, _status} ->
          :ok

        {:error, :expired} ->
          Repo.delete_all(from ps in PushSubscription, where: ps.id == ^subscription.id)

        {:error, reason} ->
          Logger.warning("Push reminder failed for subscription #{subscription.id}: #{inspect(reason)}")
      end
    end
  end
end
