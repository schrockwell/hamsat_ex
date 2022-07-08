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
      :upcoming ->
        ""

      :workable ->
        "bg-green-100 text-emerald-700 font-semibold"

      p when p in [:in_progress, :before_workable, :after_workable] ->
        "bg-yellow-100 text-yellow-800 font-semibold"

      :passed ->
        "text-gray-400"
    end
  end
end
