defmodule Hamsat.Alerts.Chat do
  @moduledoc """
  Realtime chat attached to an activation alert.

  Chat is only available on alerts that opted in (`chat_enabled`), and only
  while the chat window is open: from the moment the alert exists until 1 day
  after LOS.
  """

  use Hamsat, :repo

  alias Hamsat.Accounts.User
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.ChatMessage

  @close_after_seconds 24 * 60 * 60

  def closes_at(%Alert{} = alert), do: DateTime.add(alert.los_at, @close_after_seconds)

  @doc """
  Returns the chat status of an alert at a moment in time.

    * `:disabled` - the activator did not enable chat for this alert
    * `:open` - chat is open for posting
    * `:closed` - chat has closed
  """
  def status(%Alert{chat_enabled: false}, _now), do: :disabled

  def status(%Alert{} = alert, now) do
    if DateTime.compare(now, closes_at(alert)) == :gt, do: :closed, else: :open
  end

  def open?(%Alert{} = alert, now), do: status(alert, now) == :open

  @doc """
  The name a user posts under: their callsign, if they have one, otherwise
  "User " plus the first segment of their id.
  """
  def username(%User{callsign: callsign}) when is_binary(callsign) and callsign != "", do: callsign
  def username(%User{id: id}), do: "User #{String.slice(id, 0, 4)}"

  def subscribe(%Alert{} = alert) do
    Phoenix.PubSub.subscribe(Hamsat.PubSub, topic(alert))
  end

  def topic(%Alert{id: alert_id}), do: "alert_chat:#{alert_id}"
  def topic(alert_id) when is_binary(alert_id), do: "alert_chat:#{alert_id}"

  def change_message(params \\ %{}) do
    ChatMessage.changeset(%ChatMessage{}, params)
  end

  @doc """
  Lists an alert's chat messages, oldest first.
  """
  def list_messages(%Alert{} = alert) do
    Repo.all(
      from m in ChatMessage,
        where: m.alert_id == ^alert.id,
        order_by: [asc: m.inserted_at, asc: m.id],
        preload: [:user]
    )
  end

  @doc """
  Returns a map of alert id => chat message count for the given alert ids.
  Alerts with no messages are absent from the map.
  """
  def message_counts(alert_ids) do
    Repo.all(
      from m in ChatMessage,
        where: m.alert_id in ^alert_ids,
        group_by: m.alert_id,
        select: {m.alert_id, count(m.id)}
    )
    |> Map.new()
  end

  @doc """
  Posts a chat message to an alert.

  Only signed-in users may post, and only while the chat window is open.
  """
  def send_message(user, alert, params, now \\ nil)

  def send_message(:guest, %Alert{}, _params, _now), do: {:error, :not_signed_in}

  def send_message(%User{} = user, %Alert{} = alert, params, now) do
    now = now || DateTime.utc_now()

    if open?(alert, now) do
      changeset =
        %ChatMessage{alert_id: alert.id, user_id: user.id}
        |> ChatMessage.changeset(params)

      with {:ok, message} <- Repo.insert(changeset) do
        message = %{message | user: user}
        Hamsat.PubSub.broadcast_chat_message(message)
        {:ok, message}
      end
    else
      {:error, :chat_closed}
    end
  end
end
