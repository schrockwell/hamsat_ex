defmodule HamsatWeb.PageFooterTest do
  use HamsatWeb.ConnCase

  test "static pages render the keps timestamp in the footer", %{conn: conn} do
    html = conn |> get(~p"/about") |> html_response(200)
    assert html =~ ~r/Keps updated (just now|\d+h ago)/
  end
end
