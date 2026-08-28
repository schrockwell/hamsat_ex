defmodule HamsatWeb.PassesShowTest do
  use HamsatWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Hamsat.Coord
  alias Hamsat.Factory
  alias Hamsat.Passes

  @observer %Coord{lat: 41.5, lon: -73.0}

  setup do
    Factory.satellite(%{}, :ao_7, "AO-7")
  end

  defp upcoming_pass(sat) do
    [pass | _] = Passes.list_passes(@observer, sat, ending: Timex.shift(DateTime.utc_now(), hours: 24))
    pass
  end

  test "shows the pass details for a pass hash", %{conn: conn, ao_7: ao_7} do
    pass = upcoming_pass(ao_7)

    {:ok, _view, html} = live(conn, ~p"/passes/#{pass.hash}")

    assert html =~ "pass over FN31"
    assert html =~ "Pass details"
    assert html =~ "Post an Activation"
  end

  test "the pass page uses the observer location from the hash, not the session", %{conn: conn, ao_7: ao_7} do
    pass = upcoming_pass(ao_7)

    # A viewer with a different location still sees the pass for the encoded grid
    conn = Plug.Test.init_test_session(conn, %{"lat" => -33.9, "lon" => 151.2})
    html = conn |> get(~p"/passes/#{pass.hash}") |> html_response(200)

    assert html =~ "pass over FN31"
  end

  test "redirects to the passes index for a bogus hash", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/passes"}}} = live(conn, ~p"/passes/not-a-real-hash")
  end
end
