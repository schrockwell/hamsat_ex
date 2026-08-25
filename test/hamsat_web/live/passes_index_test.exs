defmodule HamsatWeb.PassesIndexTest do
  use HamsatWeb.ConnCase

  setup %{conn: conn} do
    %{conn: Plug.Test.init_test_session(conn, %{"lat" => 41.5, "lon" => -73.0})}
  end

  test "the index shows a print button linking to the printer-friendly view", %{conn: conn} do
    html = conn |> get(~p"/passes") |> html_response(200)

    assert html =~ ~s(href="/passes?print=1")
  end

  test "the browse view's print button carries the date filter", %{conn: conn} do
    html = conn |> get(~p"/passes?date=2026-08-24") |> html_response(200)

    assert html =~ "date=2026-08-24"
    assert html =~ "print=1"
  end

  test "?print=1 renders the plain print view without the app chrome", %{conn: conn} do
    html = conn |> get(~p"/passes?print=1") |> html_response(200)

    assert html =~ "Upcoming Satellite Passes"

    # The nav bar is not rendered
    refute html =~ "Post Activation"
  end
end
