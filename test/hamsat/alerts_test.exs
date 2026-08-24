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
