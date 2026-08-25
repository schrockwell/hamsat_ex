defmodule HamsatWeb.AlertsIndexTest do
  use HamsatWeb.ConnCase

  import Hamsat.AccountsFixtures

  alias Hamsat.Alerts
  alias Hamsat.Factory
  alias Hamsat.Passes

  setup do
    %{context: context, sat: sat} =
      %{}
      |> Factory.guest_context(:context)
      |> Factory.satellite(:sat, "AO-7")

    context = %{context | user: user_fixture()}

    [pass | _] = Passes.list_passes(context, sat, ending: Timex.shift(DateTime.utc_now(), hours: 24))

    changeset =
      Alerts.change_alert(context, sat, pass, %{
        "callsign" => "WW1X",
        "grid_1" => "FN31",
        "satellite_id" => sat.id,
        "pass_hash" => pass.hash,
        "observer_lat" => 41.5,
        "observer_lon" => -73.0,
        "mhz_direction" => "down"
      })

    {:ok, alert} = Alerts.create_alert(context, changeset)

    %{alert: alert, sat: sat}
  end

  test "the index shows a print button linking to the printer-friendly view", %{conn: conn} do
    html = conn |> get(~p"/alerts") |> html_response(200)

    assert html =~ ~s(href="/alerts?print=1")
  end

  test "the browse view's print button carries the date filter", %{conn: conn, alert: alert} do
    date = alert.aos_at |> DateTime.to_date() |> Date.to_iso8601()
    html = conn |> get(~p"/alerts?#{%{date: date}}") |> html_response(200)

    assert html =~ "date=#{date}"
    assert html =~ "print=1"
  end

  test "?print=1 renders the plain print view without the app chrome", %{conn: conn, alert: alert, sat: sat} do
    html = conn |> get(~p"/alerts?print=1") |> html_response(200)

    assert html =~ "Upcoming Satellite Activations"
    assert html =~ alert.callsign
    assert html =~ sat.name

    # The nav bar is not rendered
    refute html =~ "Post Activation"
  end
end
