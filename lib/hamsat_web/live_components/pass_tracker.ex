defmodule HamsatWeb.LiveComponents.PassTracker do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias Hamsat.Schemas.Sat

  attr :pass_plot, :any, default: nil
  attr :location, :any, default: nil
  attr :id, :string, required: true
  attr :now, DateTime, required: true
  attr :sat, Sat, required: true

  def component(assigns) do
    ~H"""
    <.live_component module={__MODULE__} pass_plot={@pass_plot} id={@id} now={@now} sat={@sat} location={@location} />
    """
  end

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
      location = if socket.assigns.pass_plot, do: socket.assigns.pass_plot.location, else: socket.assigns.location

      sat_position =
        socket.assigns.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(location), magnitude?: false)

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

  defp data_path(nil), do: Jason.encode!([])
  defp data_path(pass_plot), do: Jason.encode!(pass_plot.coords)

  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="PassTrackerHook" phx-update="ignore" data-path={data_path(@pass_plot)}></div>
    """
  end
end
