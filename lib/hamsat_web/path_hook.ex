defmodule HamsatWeb.NavHook do
  import Phoenix.Component
  import Phoenix.LiveView

  alias HamsatWeb.ViewHelpers

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     attach_hook(socket, :set_path, :handle_params, fn _params, uri, socket ->
       uri = URI.parse(uri)
       {:cont, assign(socket, :active_nav_item, ViewHelpers.active_nav_item(uri.path))}
     end)}
  end
end
