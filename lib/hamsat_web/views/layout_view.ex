defmodule HamsatWeb.LayoutView do
  use HamsatWeb, :view

  import HamsatWeb.Buttons

  alias Hamsat.Grid

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def location_nav_button_text(%{context: _context} = assigns) do
    if assigns.context.location do
      ~H"""
      <span class="hidden md:inline">@</span> <%= Grid.encode!(@context.location, 4) %>
      """
    else
      ~H"""
      <Heroicons.LiveView.icon name="exclamation" type="outline" class="inline-block h-6 w-6" />
      <span class="hidden md:inline">Set Location</span>
      """
    end
  end
end
