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
  defp passes_nav_attrs(%{live?: true, context: %{location: nil}}) do
    [href: "#", "phx-click": "show-location-modal", "phx-value-redirect": ~p"/passes"]
  end

  defp passes_nav_attrs(_assigns), do: [navigate: ~p"/passes"]

  defp location_nav_attrs(%{live?: true} = assigns) do
    [href: "#", "phx-click": "show-location-modal", "phx-value-redirect": assigns.current_path || "/"]
  end

  defp location_nav_attrs(_assigns), do: [navigate: ~p"/location"]

  def page_layout(assigns) do
    assigns =
      assigns
      |> assign_new(:live?, fn -> false end)
      |> assign_new(:current_path, fn -> nil end)

    assigns =
      assign(assigns,
        passes_nav_attrs: passes_nav_attrs(assigns),
        location_nav_attrs: location_nav_attrs(assigns)
      )

    ~H"""
    <div class="md:mt-4 md:mx-4 md:px-6 md:py-2 px-3 py-1 flex items-center justify-between md:rounded-t-xl bg-gray-700 text-white shadow-md">
      <div class="flex items-center">
        <.link navigate={~p"/"} class="text-lg font-medium md:mr-8 flex items-center gap-2">
          <img src={~s"/images/logo.png"} alt="Hamsat" class="h-8 w-8" /> Hams.at
        </.link>

        <div class="hidden md:flex items-center">
          <.nav_pill_button navigate={~p"/sats"} active={@active_nav_item == :sats}>
            Sats
          </.nav_pill_button>
          <.nav_pill_button navigate={~p"/alerts"} active={@active_nav_item == :alerts}>
            Activations
          </.nav_pill_button>
          <.nav_pill_button {@passes_nav_attrs} active={@active_nav_item == :passes}>
            Passes
          </.nav_pill_button>
        </div>
      </div>

      <div class="hidden md:flex items-center">
        <%= if @context.user != :guest do %>
          <.nav_pill_button navigate={~p"/users/settings"} active={@active_nav_item == :settings} class="flex items-center">
            Settings
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
        <.nav_pill_button {@passes_nav_attrs} active={@active_nav_item == :passes}>
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
      <.link {@location_nav_attrs} class="hover:underline hover:text-gray-700">
        <%= if @context.location do %>
          <%= Grid.encode!(@context.location, 4) %>
        <% else %>
          Set Location
        <% end %>
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
      ·
      DE
      <.link href="https://mastodon.hams.social/@ww1x" class="hover:underline hover:text-gray-700">
        WW1X
      </.link>
    </div>
    """
  end
end
