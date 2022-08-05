defmodule HamsatWeb.Alerts.Components.AlertTableRow do
  use HamsatWeb, :love_component

  alias Hamsat.Grid
  alias Hamsat.Schemas.Alert
  alias HamsatWeb.LiveComponents.AlertSaver

  prop :alert
  prop :context
  prop :now

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
