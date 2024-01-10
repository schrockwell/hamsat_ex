defmodule HamsatWeb.SatTracker do
  use HamsatWeb, :live_component

  prop :activator_position
  prop :mapbox_access_token, default: Application.fetch_env!(:hamsat, :mapbox_access_token)
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

  defp observer_coords(positions) do
    for pos <- positions, do: [pos.lat, pos.lon]
  end
end
