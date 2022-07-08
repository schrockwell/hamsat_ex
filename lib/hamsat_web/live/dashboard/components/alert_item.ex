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
        Alert.progression(socket.assigns.alert, socket.assigns.now) == :workable
      )
    else
      assign(socket, :sat_visible?, false)
    end
  end
end
