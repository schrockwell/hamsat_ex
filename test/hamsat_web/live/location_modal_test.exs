defmodule HamsatWeb.LocationModalTest do
  use HamsatWeb.ConnCase

  import Phoenix.LiveViewTest

  test "passes page prompts for location and opens the modal", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/passes")

    # The inline picker is replaced by a prompt that opens the modal
    assert html =~ "show-location-modal"
    assert html =~ ~s(phx-value-redirect="/passes")

    # Clicking the prompt opens the modal containing the child LiveView
    html = view |> element("main button", "Set Location") |> render_click()
    assert html =~ ~s(id="location-modal")

    child = find_live_child(view, "location-modal-live")
    assert child

    child_html = render(child)
    assert child_html =~ ~s(action="/session_location")
    assert child_html =~ ~s(name="redirect" value="/passes")

    # The close button dismisses the modal
    html = view |> element(~s{#location-modal button[aria-label="Close"]}) |> render_click()
    refute html =~ ~s(id="location-modal")
  end

  test "footer Set Location link opens the modal with the current path as redirect", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/")

    assert html =~ "Set Location"

    view |> element("a", "Set Location") |> render_click()

    child = find_live_child(view, "location-modal-live")
    assert child
    assert render(child) =~ ~s(name="redirect" value="/")
  end

  test "nav Passes button opens the modal when location is not set", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")

    assert html =~ ~s(phx-value-redirect="/passes")
  end

  test "footer grid link opens the modal when location is set", %{conn: conn} do
    conn = Plug.Test.init_test_session(conn, %{"lat" => 42.36, "lon" => -71.06})
    {:ok, view, html} = live(conn, ~p"/")

    # Passes nav navigates normally when a location is set
    refute html =~ ~s(phx-value-redirect="/passes")

    view |> element(~s{a[phx-click="show-location-modal"]}) |> render_click()

    assert find_live_child(view, "location-modal-live")
  end
end
