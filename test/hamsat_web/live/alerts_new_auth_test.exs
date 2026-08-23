defmodule HamsatWeb.AlertsNewAuthTest do
  use HamsatWeb.ConnCase

  import Phoenix.LiveViewTest

  test "guests are redirected to log in on a direct request", %{conn: conn} do
    conn = get(conn, ~p"/alerts/new")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  test "guests are redirected to log in on live navigation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    # Live navigation bypasses the router plug, so the on_mount hook must halt
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live_redirect(view, to: ~p"/alerts/new")
  end
end
