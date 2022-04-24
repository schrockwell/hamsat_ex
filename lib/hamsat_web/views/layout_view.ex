defmodule HamsatWeb.LayoutView do
  use HamsatWeb, :view

  import HamsatWeb.Buttons
  import Plug.Conn

  alias Hamsat.Coord
  alias Hamsat.Grid

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def location_nav_button_text(conn) do
    cond do
      conn.assigns.current_user ->
        grid =
          %Coord{lat: conn.assigns.current_user.home_lat, lon: conn.assigns.current_user.home_lon}
          |> Grid.encode!(4)

        "@ #{grid}"

      get_session(conn, :lat) && get_session(conn, :lon) ->
        grid =
          %Coord{lat: get_session(conn, :lat), lon: get_session(conn, :lon)}
          |> Grid.encode!(4)

        "@ #{grid}"

      true ->
        "Set Location"
    end
  end
end
