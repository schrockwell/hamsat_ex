defmodule HamsatWeb.Location.EditLive do
  use HamsatWeb, :live_view

  alias Hamsat.Context

  alias HamsatWeb.LocationPicker

  def mount(_params, _session, socket) do
    coords =
      case Context.get_observer(socket.assigns.context) do
        nil -> {0, 0}
        obs -> {obs.latitude_deg, obs.longitude_deg}
      end

    socket = assign(socket, :coords, coords)

    {:ok, socket}
  end
end
