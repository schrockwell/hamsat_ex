defmodule HamsatWeb.SatTracker do
  use HamsatWeb, :live_component

  def mount(socket) do
    {:ok,
     socket
     |> assign(:mapbox_access_token, Application.fetch_env!(:hamsat, :mapbox_access_token))
     |> assign(:sat_position, nil)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> push_sat_position()
      |> push_observer_position()
      |> push_activator_position()

    {:ok, socket}
  end

  def push_sat_position(socket) do
    if changed?(socket, :sat_position) do
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
    else
      socket
    end
  end

  def push_observer_position(socket) do
    if changed?(socket, :observer_position) do
      push_position(socket, "set-observer-position", socket.assigns.observer_position)
    else
      socket
    end
  end

  def push_activator_position(socket) do
    if changed?(socket, :activator_position) do
      push_position(socket, "set-activator-position", socket.assigns.activator_position)
    else
      socket
    end
  end

  defp push_position(socket, event, coord) do
    payload = %{
      "id" => "sat-tracker-map",
      "coord" => %{"lat" => coord.lat, "lon" => coord.lon}
    }

    push_event(socket, event, payload)
  end
end
