defmodule HamsatWeb.Alerts.Components.AlertTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.LiveComponents.AlertSaver

  prop :alert
  prop :context
  prop :now

  state :row_class
  state :next_workable_in

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

  @react to: [:alert, :now]
  defp assign_row_class(socket) do
    put_state(socket, row_class: alert_table_row_class(socket.assigns.alert, socket.assigns.now))
  end

  @react to: [:alert, :now]
  defp assign_next_workable_in(socket) do
    put_state(socket, next_workable_in: alert_next_workable_in(socket.assigns.now, socket.assigns.alert))
  end
end
