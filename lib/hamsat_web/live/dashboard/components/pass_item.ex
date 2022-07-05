defmodule HamsatWeb.Dashboard.Components.PassItem do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts.Pass
  alias HamsatWeb.SatComponents

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_root_class()

    {:ok, socket}
  end

  defp assign_root_class(socket) do
    if changed?(socket, :now) do
      root_class =
        case Pass.progression(socket.assigns.pass, socket.assigns.now) do
          :upcoming -> nil
          :in_progress -> "bg-yellow-100"
          :passed -> "text-gray-400"
        end

      assign(socket, :root_class, root_class)
    else
      socket
    end
  end
end
