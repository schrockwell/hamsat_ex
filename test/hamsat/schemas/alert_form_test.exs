defmodule Hamsat.Schemas.AlertFormTest do
  use ExUnit.Case, async: true

  alias Hamsat.Schemas.AlertForm
  alias Hamsat.Schemas.FreqRange
  alias Hamsat.Schemas.Sat
  alias Hamsat.Schemas.Transponder

  describe "mhz_out_of_range?/2" do
    # A linear transponder plus a fixed-frequency FM channel, like AO-91-era
    # birds combined into one test sat
    defp test_sat do
      %Sat{
        modulations: [:linear, :fm],
        transponders: [
          %Transponder{
            mode: :linear,
            downlink: %FreqRange{lower_mhz: 145.9, upper_mhz: 145.98},
            uplink: %FreqRange{lower_mhz: 435.1, upper_mhz: 435.18}
          },
          %Transponder{
            mode: :fm,
            downlink: %FreqRange{lower_mhz: 436.795, upper_mhz: 436.795},
            uplink: %FreqRange{lower_mhz: 145.99, upper_mhz: 145.99}
          }
        ]
      }
    end

    defp out_of_range?(sat, params) do
      AlertForm.mhz_out_of_range?(sat, AlertForm.changeset(nil, sat, nil, params))
    end

    test "false when the frequency is within a matching subband" do
      refute out_of_range?(test_sat(), %{"mhz" => "145.95", "mhz_direction" => "down", "mode" => "SSB"})
    end

    test "false at the exact subband boundaries" do
      refute out_of_range?(test_sat(), %{"mhz" => "145.9", "mhz_direction" => "down", "mode" => "SSB"})
      refute out_of_range?(test_sat(), %{"mhz" => "145.98", "mhz_direction" => "down", "mode" => "SSB"})
    end

    test "true when the frequency is outside all matching subbands" do
      assert out_of_range?(test_sat(), %{"mhz" => "146.5", "mhz_direction" => "down", "mode" => "SSB"})
    end

    test "checks uplink subbands when the direction is up" do
      refute out_of_range?(test_sat(), %{"mhz" => "435.15", "mhz_direction" => "up", "mode" => "SSB"})
      assert out_of_range?(test_sat(), %{"mhz" => "145.95", "mhz_direction" => "up", "mode" => "SSB"})
    end

    test "false when no frequency is entered" do
      refute out_of_range?(test_sat(), %{"mhz_direction" => "down", "mode" => "SSB"})
    end

    test "false when the satellite has no subbands for the selection" do
      sat = %Sat{modulations: [:linear], transponders: []}
      refute out_of_range?(sat, %{"mhz" => "146.5", "mhz_direction" => "down", "mode" => "SSB"})
    end
  end

  describe "grids_centroid/1" do
    test "returns the center of a single grid" do
      assert {:ok, {lat, lon}} = AlertForm.grids_centroid(["FL15"])
      assert_in_delta lat, 25.5, 0.001
      assert_in_delta lon, -77.0, 0.001
    end

    test "ignores blank and nil grids" do
      assert {:ok, {lat, lon}} = AlertForm.grids_centroid(["FL15", "", nil, nil])
      assert_in_delta lat, 25.5, 0.001
      assert_in_delta lon, -77.0, 0.001
    end

    test "returns the centroid of multiple grids" do
      # FN31 center is {41.5, -73.0}, FN41 center is {41.5, -71.0}
      assert {:ok, {lat, lon}} = AlertForm.grids_centroid(["FN31", "FN41"])
      assert_in_delta lat, 41.5, 0.001
      assert_in_delta lon, -72.0, 0.001
    end

    test "accepts six-character grids" do
      assert {:ok, {lat, lon}} = AlertForm.grids_centroid(["FN31pr"])
      assert_in_delta lat, 41.729, 0.001
      assert_in_delta lon, -72.708, 0.001
    end

    test "returns :error when any present grid is invalid" do
      assert AlertForm.grids_centroid(["FN31", "XY"]) == :error
    end

    test "returns :error when no grids are present" do
      assert AlertForm.grids_centroid([]) == :error
      assert AlertForm.grids_centroid([nil, "", nil, nil]) == :error
    end
  end
end
