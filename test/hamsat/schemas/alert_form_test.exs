defmodule Hamsat.Schemas.AlertFormTest do
  use ExUnit.Case, async: true

  alias Hamsat.Schemas.AlertForm

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
