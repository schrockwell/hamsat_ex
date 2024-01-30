defmodule HamsatWeb.API.AlertsView do
  use HamsatWeb, :view

  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  def render("index.json", %{alerts: alerts, format: format}) do
    %{data: Enum.map(alerts, &alert(&1, format))}
  end

  # {
  #   "date": "2024-01-29",
  #   "start_time": "23:14:40",
  #   "end_time": "00:31:45",
  #   "callsign": "JR5JAQ/6",
  #   "satellite": "GREENCUBE",
  #   "gridsquare": "PM62/PM53",
  #   "frequency": "435.310↑",
  #   "mode": "Data",
  #   "comment": "“#44 OITA Pref  (PM62) or(PM53)”",
  #   "track_link": "https://hams.at/alerts/36aabf33-0932-49e5-9579-d93c185406aa"
  #   },
  defp alert(%Alert{} = alert, :cloudlog) do
    %{
      date: Date.to_iso8601(alert.aos_at),
      start_time: Time.to_iso8601(alert.aos_at),
      end_time: Time.to_iso8601(alert.los_at),
      callsign: alert.callsign,
      satellite: alert.sat.name,
      gridsquare: Enum.join(alert.grids, "/"),
      frequency: "#{mhz(alert, 3)}",
      mode: alert.mode,
      comment: alert.comment,
      track_link: url(~p"/alerts/#{alert.id}")
    }
  end

  defp alert(%Alert{} = alert, :default) do
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
