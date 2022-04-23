defmodule HamsatWeb.ViewHelpers do
  alias Hamsat.Alerts.Pass
  alias Hamsat.Context

  def date(context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!("{YYYY}-{0M}-{0D}")
  end

  def time(context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!("{h24}:{m}:{s}")
  end

  defp normalize_datetime(%DateTime{} = datetime), do: datetime
  defp normalize_datetime(erl_datetime), do: Hamsat.Util.erl_to_utc_datetime(erl_datetime)

  def pass_duration(%Pass{} = pass) do
    pass.info.los.datetime
    |> Timex.diff(pass.info.aos.datetime, :second)
    |> hms()
  end

  def hms(seconds) do
    sign = if seconds < 0, do: "-", else: ""
    seconds = abs(seconds)

    hours = floor(seconds / 3600)
    seconds = seconds - hours * 3600

    minutes = floor(seconds / 60)
    seconds = seconds - minutes * 60

    case {hours, minutes, seconds} do
      {0, 0, s} -> "#{sign}0:#{zero_pad(s)}"
      {0, m, s} -> "#{sign}#{m}:#{zero_pad(s)}"
      {h, m, s} -> "#{sign}#{h}:#{zero_pad(m)}:#{zero_pad(s)}"
    end
  end

  defp zero_pad(int) when int < 10, do: "0#{int}"
  defp zero_pad(int), do: to_string(int)

  def pass_max_el(%Pass{} = pass) do
    (pass.info.max.elevation_in_degrees |> round() |> to_string()) <> "°"
  end

  def pass_sat_name(%Pass{} = pass) do
    pass.sat.name
  end

  @cardinal_directions {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}

  def cardinal_direction(deg) do
    index =
      (deg + 22.5)
      |> round()
      |> rem(360)
      |> div(45)

    elem(@cardinal_directions, index)
  end

  def pass_aos_direction(%Pass{} = pass) do
    cardinal_direction(pass.info.aos.azimuth_in_degrees)
  end

  def pass_los_direction(%Pass{} = pass) do
    cardinal_direction(pass.info.los.azimuth_in_degrees)
  end

  def pass_aos_in(now, %Pass{} = pass) do
    pass.info.aos.datetime
    |> Timex.diff(now, :second)
    |> hms()
  end
end
