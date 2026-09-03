defmodule AlertsTest do
  use Hamsat.DataCase

  import Hamsat.AccountsFixtures

  alias Hamsat.Alerts
  alias Hamsat.Passes

  @one_day [ending: Timex.shift(DateTime.utc_now(), hours: 24)]

  setup do
    %{}
    |> Factory.guest_context(:context)
    |> Factory.satellite(:ao_7, "AO-7")
    |> Factory.satellite(:ao_73, "AO-73")
  end

  describe "upcoming satellite passes" do
    test "can be listed for one satellite", %{context: context, ao_7: ao_7} do
      passes = Passes.list_passes(context, ao_7, @one_day)

      assert passes != []
      assert Enum.all?(passes, &(&1.sat.id == ao_7.id))
    end

    test "can be listed for many satellites", %{context: context, ao_7: ao_7, ao_73: ao_73} do
      passes = Passes.list_all_passes(context, [ao_7, ao_73], @one_day)
      sat_ids = passes |> Enum.map(& &1.sat.id) |> Enum.uniq()

      assert ao_7.id in sat_ids
      assert ao_73.id in sat_ids
    end
  end

  describe "activation alerts" do
    setup %{context: context} do
      %{context: %{context | user: user_fixture()}}
    end

    test "can be created with valid attributes", %{context: context, ao_7: ao_7} do
      [pass | _] = Passes.list_passes(context, ao_7, @one_day)

      changeset = Alerts.change_alert(context, ao_7, pass, alert_params(ao_7, pass, "WW1X"))

      assert {:ok, alert} = Alerts.create_alert(context, changeset)
      assert alert.satellite_id == ao_7.id
      assert alert.callsign == "WW1X"
      assert alert.user_id == context.user.id

      # The activator's own thumbs-up is saved automatically
      assert Repo.get_by(Hamsat.Schemas.SavedAlert, alert_id: alert.id, user_id: context.user.id)
    end

    test "fail creation with invalid attributes", %{context: context, ao_7: ao_7} do
      [pass | _] = Passes.list_passes(context, ao_7, @one_day)

      changeset = Alerts.change_alert(context, ao_7, pass, alert_params(ao_7, pass, ""))

      assert {:error, %Ecto.Changeset{}} = Alerts.create_alert(context, changeset)
    end
  end

  describe "test alerts" do
    setup %{context: context, ao_7: ao_7} do
      owner_context = %{context | user: user_fixture()}
      other_context = %{context | user: user_fixture()}
      [pass | _] = Passes.list_passes(owner_context, ao_7, @one_day)

      {:ok, real} =
        Alerts.create_alert(
          other_context,
          Alerts.change_alert(other_context, ao_7, pass, alert_params(ao_7, pass, "W1AW"))
        )

      {:ok, test_alert} =
        Alerts.create_alert(
          owner_context,
          Alerts.change_alert(owner_context, ao_7, pass, alert_params(ao_7, pass, "WW1X")),
          test: true
        )

      %{
        guest_context: context,
        owner_context: owner_context,
        other_context: other_context,
        pass: pass,
        real: real,
        test_alert: test_alert
      }
    end

    test "are flagged and skip preference updates", %{owner_context: context, test_alert: test_alert} do
      assert test_alert.is_test
      assert Repo.get!(Hamsat.Accounts.User, context.user.id).latest_callsign == nil
    end

    test "are listed only for their owner", %{
      guest_context: guest,
      owner_context: owner,
      other_context: other,
      real: real,
      test_alert: test_alert
    } do
      assert ids(Alerts.list_alerts(guest)) == [real.id]
      assert ids(Alerts.list_alerts(other)) == [real.id]
      assert ids(Alerts.list_alerts(owner)) == Enum.sort([real.id, test_alert.id])
      assert Alerts.count_alerts(guest) == 1
      assert Alerts.count_alerts(owner) == 2
    end

    test "are listed for everyone with test: :all", %{
      guest_context: guest,
      real: real,
      test_alert: test_alert
    } do
      assert ids(Alerts.list_alerts(guest, test: :all)) == Enum.sort([real.id, test_alert.id])
    end

    test "can only be fetched by their owner", %{
      guest_context: guest,
      owner_context: owner,
      test_alert: test_alert
    } do
      assert {:error, :not_found} = Alerts.get_alert(guest, test_alert.id)
      assert {:ok, _} = Alerts.get_alert(guest, test_alert.id, test: :all)
      assert {:ok, _} = Alerts.get_alert(owner, test_alert.id)

      assert_raise Ecto.NoResultsError, fn -> Alerts.get_alert!(guest, test_alert.id) end
      assert Alerts.get_alert!(owner, test_alert.id).id == test_alert.id
    end

    test "are attached to passes only for their owner", %{
      guest_context: guest,
      owner_context: owner,
      ao_7: ao_7,
      pass: pass,
      real: real,
      test_alert: test_alert
    } do
      opts = [starting: pass_max_at(pass), ending: pass_max_at(pass)]

      [guest_pass] = Passes.list_passes(guest, ao_7, opts)
      assert ids(guest_pass.alerts) == [real.id]

      [owner_pass] = Passes.list_passes(owner, ao_7, opts)
      assert ids(owner_pass.alerts) == Enum.sort([real.id, test_alert.id])
    end

    defp ids(alerts), do: alerts |> Enum.map(& &1.id) |> Enum.sort()

    defp pass_max_at(pass), do: Hamsat.Util.erl_to_utc_datetime(pass.info.max.datetime)
  end

  defp alert_params(sat, pass, callsign) do
    %{
      "callsign" => callsign,
      "grid_1" => "FN31",
      "satellite_id" => sat.id,
      "pass_hash" => pass.hash,
      "observer_lat" => 41.5,
      "observer_lon" => -73.0,
      "mhz_direction" => "down"
    }
  end
end
