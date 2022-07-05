defmodule HamsatWeb.Dashboard.Components.PassItem do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
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
        Pass.progression(socket.assigns.pass, socket.assigns.now) == :in_progress
      )
    else
      socket
    end
  end
end
