defmodule HamsatWeb.Presence do
  @moduledoc """
  Presence tracking for activation pages.

  Logged-in users viewing an alert page are tracked on the alert's chat topic,
  so the chat header can show how many people are here. Presence diffs are
  broadcast on the same topic the chat subscribes to.
  """

  use Phoenix.Presence, otp_app: :hamsat, pubsub_server: Hamsat.PubSub

  alias Hamsat.Alerts.Chat

  def track_alert_viewer(pid, alert, user) do
    track(pid, Chat.topic(alert), user.id, %{})
  end

  @doc """
  The number of distinct logged-in users currently on the alert's page.
  """
  def count_alert_viewers(alert) do
    alert |> Chat.topic() |> list() |> map_size()
  end
end
