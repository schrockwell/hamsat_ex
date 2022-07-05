defmodule HamsatWeb.Passes.Components.PassTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias HamsatWeb.SatComponents

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     socket
     |> assign(:class, pass_table_row_class(socket.assigns.pass, socket.assigns.now))
     |> assign(:next_aos, pass_next_event_in(socket.assigns.now, socket.assigns.pass))}
  end

  defp pass_table_row_class(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming -> ""
      :in_progress -> "bg-yellow-100 text-yellow-800 font-semibold"
      :passed -> "text-gray-400"
    end
  end
end
