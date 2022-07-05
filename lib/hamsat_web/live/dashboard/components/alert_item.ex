defmodule HamsatWeb.Dashboard.Components.AlertItem do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.SatComponents

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_sat_visible()

    {:ok, socket}
  end

  defp assign_sat_visible(socket) do
    if changed?(socket, :now) do
      assign(
        socket,
        :sat_visible?,
        socket.assigns.alert.is_workable? and
          Alert.progression(socket.assigns.alert, socket.assigns.now) == :in_progress
      )
    else
      assign(socket, :sat_visible?, false)
    end
  end
end
