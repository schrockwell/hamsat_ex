defmodule HamsatWeb.Dashboard.Components.AlertItem do
  use HamsatWeb, :live_component

  alias Hamsat.Grid
  alias Hamsat.Schemas.Alert
  alias HamsatWeb.AlertComponents
  alias HamsatWeb.SatComponents
  alias HamsatWeb.LiveComponents.AlertSaver

  prop :alert
  prop :context
  prop :mine?
  prop :now

  defp sat_visible?(alert, now) do
    Alert.progression(alert, now) == :workable
  end
end
