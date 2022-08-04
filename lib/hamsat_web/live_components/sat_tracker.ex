defmodule HamsatWeb.SatTracker do
  use HamsatWeb, :love_component

  prop :activator_position
  prop :id
  prop :mapbox_access_token, default: Application.compile_env!(:hamsat, :mapbox_access_token)
  prop :observer_position
  prop :sat_position

  @react to: :sat_position
  def push_sat_position(socket) do
    sat_position = socket.assigns.sat_position

    wrapped_lon =
      if sat_position.longitude > 180,
        do: sat_position.longitude - 360,
        else: sat_position.longitude

    payload = %{
      "id" => "sat-tracker-map",
      "coord" => %{"lat" => sat_position.latitude, "lon" => wrapped_lon},
      "footprintRadius" => sat_position.footprint_radius
    }

    push_event(socket, "set-sat-position", payload)
  end

  @react to: :observer_position
  def push_observer_position(socket) do
    push_position(socket, "set-observer-position", socket.assigns.observer_position)
  end

  @react to: :activator_position
  def push_activator_position(socket) do
    push_position(socket, "set-activator-position", socket.assigns.activator_position)
  end

  defp push_position(socket, event, coord) do
    payload = %{
      "id" => "sat-tracker-map",
      "coord" => %{"lat" => coord.lat, "lon" => coord.lon}
    }

    push_event(socket, event, payload)
  end
end
