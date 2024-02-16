defmodule HamsatWeb.API.AlertsView do
  use HamsatWeb, :view

  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  def render("index.json", %{alerts: alerts}) do
    %{data: Enum.map(alerts, &alert/1)}
  end

  defp alert(%Alert{} = alert) do
    %{
      aos_at: alert.aos_at,
      callsign: alert.callsign,
      comment: alert.comment,
      grids: alert.grids,
      id: alert.id,
      los_at: alert.los_at,
      mhz_direction: alert.mhz_direction,
      mhz: alert.mhz,
      mode: alert.mode,
      satellite: sat(alert.sat),
      url: url(~p"/alerts/#{alert.id}")
    }
  end

  defp sat(%Sat{} = sat) do
    %{
      name: sat.name,
      number: sat.number
    }
  end
end
