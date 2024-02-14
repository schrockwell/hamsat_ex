defmodule HamsatWeb.SatTracker do
  use HamsatWeb, :live_component

  attr :id, :string, required: true
  attr :observer_positions, :list, required: true
  attr :sat_positions, :list, required: true

  def component(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={@id} observer_positions={@observer_positions} sat_positions={@sat_positions} />
    """
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> push_sat_positions()}
  end

  def push_sat_positions(socket) do
    if changed?(socket, :sat_positions) do
      payload = %{
        "id" => "sat-tracker-map",
        "positions" => Enum.map(socket.assigns.sat_positions, &sat_position_payload/1)
      }

      push_event(socket, "set-sat-positions", payload)
    else
      socket
    end
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
