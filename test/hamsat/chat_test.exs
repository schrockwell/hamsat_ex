defmodule Hamsat.Alerts.ChatTest do
  use Hamsat.DataCase

  import Hamsat.AccountsFixtures

  alias Hamsat.Alerts.Chat
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.ChatMessage
  alias Hamsat.Schemas.Sat

  setup do
    user = user_fixture(%{home_lat: 41.0, home_lon: -73.0, callsign: "WW1X"})

    unique = System.unique_integer([:positive])

    sat =
      Repo.insert!(%Sat{
        number: 900_000 + unique,
        name: "TEST-#{unique}",
        slug: "test-#{unique}",
        nasa_name: "TEST-#{unique}"
      })

    alert = insert_alert(user, sat, chat_enabled: true)

    %{user: user, sat: sat, alert: alert}
  end

  defp insert_alert(user, sat, opts) do
    aos_at = Keyword.get(opts, :aos_at, DateTime.utc_now() |> DateTime.truncate(:second))
    los_at = Keyword.get(opts, :los_at, DateTime.add(aos_at, 10 * 60))

    Repo.insert!(%Alert{
      satellite_id: sat.id,
      user_id: user.id,
      callsign: "WW1X",
      aos_at: aos_at,
      max_at: DateTime.add(aos_at, 5 * 60),
      los_at: los_at,
      observer_lat: 41.0,
      observer_lon: -73.0,
      mhz_direction: :down,
      grids: ["FN31"],
      chat_enabled: Keyword.get(opts, :chat_enabled, false)
    })
  end

  describe "status/2" do
    test "is :disabled when the alert did not opt in to chat", %{user: user, sat: sat} do
      alert = insert_alert(user, sat, chat_enabled: false)

      assert Chat.status(alert, DateTime.utc_now()) == :disabled
      refute Chat.open?(alert, DateTime.utc_now())
    end

    test "opens 5 minutes before AOS and closes 60 minutes after LOS", %{alert: alert} do
      just_before_open = DateTime.add(alert.aos_at, -5 * 60 - 1)
      at_open = DateTime.add(alert.aos_at, -5 * 60)
      during = DateTime.add(alert.aos_at, 60)
      at_close = DateTime.add(alert.los_at, 60 * 60)
      just_after_close = DateTime.add(alert.los_at, 60 * 60 + 1)

      assert Chat.status(alert, just_before_open) == :before
      assert Chat.status(alert, at_open) == :open
      assert Chat.status(alert, during) == :open
      assert Chat.status(alert, at_close) == :open
      assert Chat.status(alert, just_after_close) == :closed
    end
  end

  describe "username/1" do
    test "uses the user's callsign", %{user: user} do
      assert Chat.username(user) == "WW1X"
    end

    test "falls back to a shortened user id" do
      user = user_fixture(%{home_lat: 41.0, home_lon: -73.0})

      assert Chat.username(user) == "User #{String.slice(user.id, 0, 4)}"
    end
  end

  describe "send_message/3" do
    test "inserts and broadcasts a message while chat is open", %{user: user, alert: alert} do
      Chat.subscribe(alert)

      assert {:ok, message} = Chat.send_message(user, alert, %{"body" => "  Hello there  "})
      assert message.body == "Hello there"
      assert message.user_id == user.id
      assert message.alert_id == alert.id

      assert_receive {:chat_message, %ChatMessage{body: "Hello there"}}

      assert [%ChatMessage{body: "Hello there"}] = Chat.list_messages(alert)
    end

    test "rejects a blank message", %{user: user, alert: alert} do
      assert {:error, %Ecto.Changeset{}} = Chat.send_message(user, alert, %{"body" => "   "})
      assert Chat.list_messages(alert) == []
    end

    test "rejects guests", %{alert: alert} do
      assert {:error, :not_signed_in} = Chat.send_message(:guest, alert, %{"body" => "hi"})
    end

    test "rejects messages before the chat window opens", %{user: user, sat: sat} do
      aos_at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)
      alert = insert_alert(user, sat, chat_enabled: true, aos_at: aos_at)

      assert {:error, :chat_closed} = Chat.send_message(user, alert, %{"body" => "hi"})
    end

    test "rejects messages after the chat window closes", %{user: user, sat: sat} do
      aos_at = DateTime.utc_now() |> DateTime.add(-7200) |> DateTime.truncate(:second)
      alert = insert_alert(user, sat, chat_enabled: true, aos_at: aos_at)

      assert {:error, :chat_closed} = Chat.send_message(user, alert, %{"body" => "hi"})
    end

    test "rejects messages when chat is disabled", %{user: user, sat: sat} do
      alert = insert_alert(user, sat, chat_enabled: false)

      assert {:error, :chat_closed} = Chat.send_message(user, alert, %{"body" => "hi"})
    end
  end

  describe "presence" do
    test "counts distinct logged-in viewers on the alert page", %{user: user, alert: alert} do
      assert HamsatWeb.Presence.count_alert_viewers(alert) == 0

      {:ok, _} = HamsatWeb.Presence.track_alert_viewer(self(), alert, user)
      assert HamsatWeb.Presence.count_alert_viewers(alert) == 1

      # The same user in a second tab still counts once
      second_tab = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _} = HamsatWeb.Presence.track_alert_viewer(second_tab, alert, user)
      assert HamsatWeb.Presence.count_alert_viewers(alert) == 1

      other_user = user_fixture(%{callsign: "N0CALL"})
      other_tab = spawn(fn -> Process.sleep(:infinity) end)
      {:ok, _} = HamsatWeb.Presence.track_alert_viewer(other_tab, alert, other_user)
      assert HamsatWeb.Presence.count_alert_viewers(alert) == 2

      Process.exit(second_tab, :kill)
      Process.exit(other_tab, :kill)
    end
  end

  describe "alert preferences" do
    test "creating an alert remembers the user's chat preference", %{user: user, alert: alert} do
      assert user.prefer_chat_enabled

      updated = Hamsat.Accounts.update_alert_preferences!(user, %{alert | chat_enabled: false})
      refute updated.prefer_chat_enabled

      updated = Hamsat.Accounts.update_alert_preferences!(updated, %{alert | chat_enabled: true})
      assert updated.prefer_chat_enabled
    end
  end
end
