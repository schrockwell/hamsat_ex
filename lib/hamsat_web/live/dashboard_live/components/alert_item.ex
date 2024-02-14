defmodule HamsatWeb.DashboardLive.Components.AlertItem do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.AlertComponents
  alias HamsatWeb.SatComponents
  alias HamsatWeb.LiveComponents.AlertSaver

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :id, :string, required: true
  attr :mine?, :boolean, required: true
  attr :now, DateTime, required: true

  def component(assigns) do
    ~H"""
    <.live_component module={__MODULE__} alert={@alert} context={@context} id={@id} mine?={@mine?} now={@now} />
    """
  end

  defp sat_visible?(alert, now) do
    Alert.progression(alert, now) == :workable
  end
end
