defmodule HamsatWeb.LiveComponents.PassTracker do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias Hamsat.Schemas.Sat

  prop :pass_plot
  prop :now
  prop :sat

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> update_sat_position()

    {:ok, socket}
  end

  defp update_sat_position(socket) do
    if changed?(socket, :now) do
      sat_position =
        socket.assigns.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(socket.assigns.pass_plot.location), magnitude?: false)

      socket
      |> assign(:sat_position, sat_position)
      |> push_sat_position()
    else
      socket
    end
  end

  defp push_sat_position(socket) do
    if changed?(socket, :sat_position) do
      push_event(socket, "move_satellite", %{
        "id" => socket.assigns.id,
        "az" => socket.assigns.sat_position.azimuth_in_degrees,
        "el" => socket.assigns.sat_position.elevation_in_degrees
      })
    else
      socket
    end
  end

  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="PassTrackerHook" phx-update="ignore" data-path={Jason.encode!(@pass_plot.coords)}></div>
    """
  end
end
