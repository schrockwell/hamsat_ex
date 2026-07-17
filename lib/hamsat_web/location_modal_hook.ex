defmodule HamsatWeb.LocationModalHook do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:location_modal_redirect, nil)
     |> attach_hook(:location_modal, :handle_event, &handle_event/3)}
  end

  defp handle_event("show-location-modal", params, socket) do
    redirect = params["redirect"] || socket.assigns[:current_path] || "/"

    # Only allow local paths as redirect destinations
    redirect = if String.starts_with?(redirect, "/"), do: redirect, else: "/"

    {:halt, assign(socket, :location_modal_redirect, redirect)}
  end

  defp handle_event("hide-location-modal", _params, socket) do
    {:halt, assign(socket, :location_modal_redirect, nil)}
  end

  defp handle_event(_event, _params, socket), do: {:cont, socket}
end
