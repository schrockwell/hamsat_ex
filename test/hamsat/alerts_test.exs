defmodule AlertsTest do
  use Hamsat.DataCase

  alias Hamsat.Alerts

  setup do
    %{}
    |> Factory.guest_context(:context)
    |> Factory.satellite(:ao_7, "AO-7")
    |> Factory.satellite(:ao_73, "AO-73")
  end

  describe "upcoming satellite passes" do
    test "can be listed for one satellite", %{context: context, ao_7: ao_7} do
      [_] = Alerts.list_passes(context, ao_7, count: 1)
      [_, _] = Alerts.list_passes(context, ao_7, count: 2)
    end

    test "can be listed for many satellites", %{context: context, ao_7: ao_7, ao_73: ao_73} do
      [_, _] = Alerts.list_all_passes(context, [ao_7, ao_73], count: 1)
      [_, _, _, _] = Alerts.list_all_passes(context, [ao_7, ao_73], count: 2)
    end
  end

  describe "activation alerts" do
    test "can be inserted with valid attributes", %{context: context, ao_7: ao_7} do
      [pass] = Alerts.list_passes(context, ao_7, count: 1)

      assert {:ok, alert} = Alerts.create_alert(context, pass, %{callsign: "WW1X"})

      assert alert.satellite_id
    end

    test "fail insertion with invalid attributes", %{context: context, ao_7: ao_7} do
      [pass] = Alerts.list_passes(context, ao_7, count: 1)

      assert {:error, _changeset} = Alerts.create_alert(context, pass, %{callsign: ""})
    end
  end
end
