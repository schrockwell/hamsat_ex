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
      url: url(~p"/alerts/#{alert.id}"),
      match_percent: alert.match && round(alert.match.total * 100),
      max_elevation: alert.max_elevation && Float.round(alert.max_elevation, 1),
      is_workable: alert.is_workable?,
      workable_start_at: alert.workable_start_at,
      workable_end_at: alert.workable_end_at,
      likes: alert.saved_count
    }
  end

  defp sat(%Sat{} = sat) do
    %{
      name: sat.name,
      number: sat.number
    }
  end
end
