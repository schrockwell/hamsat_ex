defmodule HamsatWeb.SatTracker do
  use HamsatWeb, :live_component

  prop :mapbox_access_token, default: Application.fetch_env!(:hamsat, :mapbox_access_token)
  prop :observer_positions
  prop :sat_positions

  @react to: :sat_positions
  def push_sat_positions(socket) do
    payload = %{
      "id" => "sat-tracker-map",
      "positions" => Enum.map(socket.assigns.sat_positions, &sat_position_payload/1)
    }

    push_event(socket, "set-sat-positions", payload)
  end

  defp sat_position_payload(map) do
    sat_position = map.position

    wrapped_lon =
      if sat_position.longitude > 180,
        do: sat_position.longitude - 360,
        else: sat_position.longitude

    %{
      "satId" => map.sat_id,
      "satName" => map[:sat_name],
      "coord" => [sat_position.latitude, wrapped_lon],
      "footprintRadius" => sat_position.footprint_radius,
      "selected" => !!map[:selected]
    }
  end

  defp observer_coords(positions) do
    for pos <- positions, do: [pos.lat, pos.lon]
  end
end
