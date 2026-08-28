defmodule HamsatWeb.LayoutView do
  use HamsatWeb, :view

  import HamsatWeb.Buttons

  alias Hamsat.Grid

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  # In a LiveView, editing the location always happens in the location modal.
  # The /location page remains as a fallback for non-LiveView pages, which
  # cannot open the modal. The Passes nav button opens the modal too when no
  # location is set yet.
  #
  # These are called inline in the template (instead of being derived assigns)
  # so change tracking only depends on the caller-passed assigns — an assign
  # added inside a function component is always flagged as changed, which made
  # these links re-send on every clock tick.
  defp passes_nav_attrs(true = _live?, %{location: nil}) do
    [href: "#", "phx-click": "show-location-modal", "phx-value-redirect": ~p"/passes"]
  end

  defp passes_nav_attrs(_live?, _context), do: [navigate: ~p"/passes"]

  defp nav_grid_label(context) do
    Grid.encode!(Hamsat.Context.effective_location(context), 4)
  end

  defp location_nav_attrs(true = _live?, current_path) do
    [href: "#", "phx-click": "show-location-modal", "phx-value-redirect": current_path || "/"]
  end

  defp location_nav_attrs(_live?, _current_path), do: [navigate: ~p"/location"]

  defp keps_updated_ago(updated_at) do
    case Timex.diff(Timex.now(), updated_at, :hours) do
      hours when hours < 1 -> "just now"
      hours -> "#{hours}h ago"
    end
  end

  def page_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:live?, fn -> false end)
      |> assign_new(:current_path, fn -> nil end)
      |> assign_new(:keps_updated_at, fn -> nil end)

    ~H"""
    <div class="md:mt-4 md:mx-4 md:px-6 md:py-2 px-3 py-1 flex items-center justify-between md:rounded-t-xl bg-gray-700 text-white shadow-md">
      <div class="flex items-center">
        <.link navigate={~p"/"} class="text-lg font-medium md:mr-8 flex items-center gap-3">
          <img src={~s"/images/logo.png"} alt="Hamsat" class="h-8 w-8" /> Hams.at
        </.link>

        <div class="hidden md:flex items-center">
          <.nav_pill_button navigate={~p"/"} active={@active_nav_item == :home}>
            Home
          </.nav_pill_button>
          <.nav_pill_button {passes_nav_attrs(@live?, @context)} active={@active_nav_item == :passes}>
            Passes
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/alerts"} active={@active_nav_item == :alerts}>
            Activations
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/sats"} active={@active_nav_item == :sats}>
            Sats
          </.nav_pill_button>
        </div>
      </div>

      <div class="hidden md:flex items-center gap-4">
        <.link
          {location_nav_attrs(@live?, @current_path)}
          title="Your grid"
          class="text-sm text-gray-300 hover:text-white transition-all whitespace-nowrap"
        >
          <%= nav_grid_label(@context) %>
        </.link>

        <%= if @context.user != :guest do %>
          <.nav_pill_button navigate={~p"/users/settings"} active={@active_nav_item == :settings} class="flex items-center">
            <%= @context.user.callsign || "Settings" %>
          </.nav_pill_button>
        <% else %>
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
        <.nav_pill_button {passes_nav_attrs(@live?, @context)} active={@active_nav_item == :passes}>
          <Heroicons.LiveView.icon name="table-cells" type="outline" class="h-6 w-6" />
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
              <Heroicons.LiveView.icon name="x-mark" type="solid" class="h-6 w-6 text-gray-400 m-2" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="md:mx-4 bg-white shadow-md md:rounded-b-xl mb-4 overflow-hidden">
      <%= render_slot(@inner_block) %>
    </div>

    <div class="my-6 text-sm text-gray-500 flex gap-1 justify-center">
      <%= if @keps_updated_at do %>
        <span title="When the satellite Keplerian elements were last updated">
          Keps updated <%= keps_updated_ago(@keps_updated_at) %>
        </span>
        ·
      <% end %>
      <%= unless @context.location do %>
        <.link {location_nav_attrs(@live?, @current_path)} class="hover:underline hover:text-gray-700">
          Set Location
        </.link>
        ·
      <% end %>
      <.link {location_nav_attrs(@live?, @current_path)} class="hover:underline hover:text-gray-700">
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
      <.link href={~p"/api/docs"} class="hover:underline hover:text-gray-700">
        API
      </.link>
      ·
      <.link navigate={~p"/about"} class="hover:underline hover:text-gray-700">
        About
      </.link>
    </div>
    """
  end
end
