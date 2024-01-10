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

  def page_layout(assigns) do
    ~H"""
    <div class="md:mt-4 md:mx-4 md:px-6 md:py-2 px-3 py-1 flex items-center justify-between md:rounded-t-xl bg-gray-700 text-white shadow-md">
      <div class="flex items-center">
        <.link navigate={~p"/"} class="text-lg font-medium md:mr-8 flex items-center gap-2">
          <img src={~s"/images/logo.png"} alt="Hamsat" class="h-8 w-8" /> Hams.at
          <span class="hidden md:inline uppercase rounded bg-orange-600 text-white text-xs px-1 py-px ml-1 font-semibold">
            Beta
          </span>
        </.link>

        <div class="hidden md:flex items-center">
          <.nav_pill_button navigate={~p"/sats"} active={@active_nav_item == :sats}>
            Sats
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/alerts"} active={@active_nav_item == :alerts}>
            Activations
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/passes"} active={@active_nav_item == :passes}>
            Passes
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/location"} active={@active_nav_item == :location}>
            <.location_nav_button_text context={@context} />
          </.nav_pill_button>
        </div>
      </div>

      <div class="hidden md:flex items-center">
        <%= if @context.user != :guest do %>
          <.nav_pill_button navigate={~p"/users/settings"} active={@active_nav_item == :settings}>
            <Heroicons.LiveView.icon name="cog" type="solid" class="h-6 w-6" />
          </.nav_pill_button>
          <.nav_pill_button href={~p"/users/log_out"} method="delete">
            Log Out
          </.nav_pill_button>
        <% else %>
          <.nav_pill_button navigate={~p"/users/register"} active={@active_nav_item == :register}>
            Register
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/users/log_in"} active={@active_nav_item == :log_in}>
            Log In
          </.nav_pill_button>
        <% end %>
      </div>

      <div class="md:hidden flex items-center">
        <.nav_pill_button navigate={~p"/sats"} active={@active_nav_item == :sats}>
          <Heroicons.LiveView.icon name="globe-alt" type="outline" class="h-6 w-6" />
        </.nav_pill_button>
        <.nav_pill_button navigate={~p"/alerts"} active={@active_nav_item == :alerts}>
          <Heroicons.LiveView.icon name="calendar" type="outline" class="h-6 w-6" />
        </.nav_pill_button>
        <.nav_pill_button navigate={~p"/passes"} active={@active_nav_item == :passes}>
          <Heroicons.LiveView.icon name="table" type="outline" class="h-6 w-6" />
        </.nav_pill_button>
        <.nav_pill_button navigate={~p"/location"} active={@active_nav_item == :location}>
          <.location_nav_button_text context={@context} />
        </.nav_pill_button>

        <button class="btn-nav" data-toggle="mobile-nav-extras">
          <Heroicons.LiveView.icon name="user" type="solid" class="h-6 w-6" />
        </button>
      </div>
    </div>

    <div id="mobile-nav-extras-wrapper" phx-update="ignore">
      <div id="mobile-nav-extras" class="p-3 hidden md:hidden bg-gray-800 text-white font-medium">
        <div class="flex justify-between items-start">
          <div>
            <%= if @context.user == :guest do %>
              <.link navigate={~p"/users/register"} class="block py-2">Register</.link>
              <.link navigate={~p"/users/log_in"} class="block py-2">Sign In</.link>
            <% else %>
              <.link navigate={~p"/users/settings"} class="block py-2">Settings</.link>
              <.link href={~p"/users/log_out"} class="block py-2" , method="delete">Log Out</.link>
            <% end %>
          </div>
          <div>
            <button data-toggle="mobile-nav-extras">
              <Heroicons.LiveView.icon name="x" type="solid" class="h-6 w-6 text-gray-400 m-2" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="md:mx-4 bg-white shadow-md md:rounded-b-xl mb-4 overflow-hidden">
      <%= render_slot(@inner_block) %>
    </div>

    <div class="my-6 text-sm text-gray-500 flex gap-1 justify-center">
      DE
      <.link href="https://mastodon.hams.social/@ww1x" class="hover:underline hover:text-gray-700">
        WW1X
      </.link>
      ·
      <.link navigate={~p"/location"} class="hover:underline hover:text-gray-700">
        <%= timezone_name(@context.timezone) %>
      </.link>
      ·
      <.link navigate={~p"/changelog"} class="hover:underline hover:text-gray-700">
        Changelog
      </.link>
      ·
      <.link href="https://github.com/schrockwell/hamsat_ex/" class="hover:underline hover:text-gray-700">
        Source
      </.link>
      ·
      <.link navigate={~p"/about"} class="hover:underline hover:text-gray-700">
        About
      </.link>
    </div>
    """
  end
end
