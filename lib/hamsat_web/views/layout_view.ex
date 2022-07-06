defmodule HamsatWeb.LayoutView do
  use HamsatWeb, :view

  import HamsatWeb.Buttons
  import Plug.Conn

  alias Hamsat.Coord
  alias Hamsat.Grid

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def location_nav_button_text(context) do
    if location = context.location do
      "@ #{Grid.encode!(location, 4)}"
    else
      "⚠️ Set Location"
    end
  end
end
