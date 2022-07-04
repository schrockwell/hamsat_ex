defmodule HamsatWeb.Alerts.Components.AlertTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_class()}
  end

  defp assign_class(socket) do
    assign(socket, :class, alert_table_row_class(socket.assigns.alert, socket.assigns.now))
  end

  defp alert_table_row_class(alert, now) do
    case Alert.progression(alert, now) do
      :upcoming -> ""
      :in_progress -> "bg-yellow-100 text-yellow-800 font-semibold"
      :passed -> "text-gray-400"
    end
  end
end
