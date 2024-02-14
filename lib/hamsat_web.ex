defmodule HamsatWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use HamsatWeb, :controller
      use HamsatWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: HamsatWeb

      import Plug.Conn
      import HamsatWeb.Gettext

      unquote(verified_routes())
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/hamsat_web/templates",
        namespace: HamsatWeb

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      # Include shared imports and aliases for views
      unquote(view_helpers())

      import HamsatWeb.LayoutComponents
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {HamsatWeb.LayoutView, :live}

      use LiveEvent.LiveView

      on_mount HamsatWeb.ContextHook
      on_mount HamsatWeb.NavHook

      unquote(view_helpers())

      import HamsatWeb.LayoutComponents
      unquote(live_inspect())
    end
  end

  defp live_inspect do
    if Mix.env() == :dev do
      quote do
        import LiveInspect, only: [live_inspect: 1]
      end
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      use LiveEvent.LiveComponent

      unquote(view_helpers())

      import HamsatWeb.LayoutComponents
      unquote(live_inspect())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      unquote(view_helpers())
    end
  end

  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import HamsatWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView and .heex helpers (live_render, live_patch, <.form>, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.Component
      import Phoenix.View

      import HamsatWeb.ErrorHelpers
      import HamsatWeb.ViewHelpers
      import HamsatWeb.Gettext

      unquote(verified_routes())
    end
  end

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: HamsatWeb.Endpoint,
        router: HamsatWeb.Router,
        statics: HamsatWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
