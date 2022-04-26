defmodule HamsatWeb.ViewHelpers do
  alias Hamsat.Alerts.Pass

  @date_format "{YYYY}-{0M}-{0D}"
  @time_format "{h24}:{m}:{s}"
  @datetime_format @date_format <> " " <> @time_format

  def date(context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!(@date_format)
  end

  def time(context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!(@time_format)
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

    days = floor(seconds / 86400)
    seconds = seconds - days * 86400

    hours = floor(seconds / 3600)
    seconds = seconds - hours * 3600

    minutes = floor(seconds / 60)
    seconds = seconds - minutes * 60

    case {days, hours, minutes, seconds} do
      {0, 0, 0, s} -> "#{sign}0:#{zero_pad(s)}"
      {0, 0, m, s} -> "#{sign}#{m}:#{zero_pad(s)}"
      {0, h, m, s} -> "#{sign}#{h}:#{zero_pad(m)}:#{zero_pad(s)}"
      {d, h, m, s} -> "#{sign}#{d}d #{h}:#{zero_pad(m)}:#{zero_pad(s)}"
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

  def date_span(start_datetime, end_datetime) do
    if Timex.to_date(start_datetime) == Timex.to_date(end_datetime) do
      Timex.format!(start_datetime, @date_format)
    else
      Timex.format!(start_datetime, @date_format) <>
        " – " <> Timex.format!(end_datetime, @date_format)
    end
  end

  def time_span(start_datetime, end_datetime) do
    if Timex.to_date(start_datetime) == Timex.to_date(end_datetime) do
      Timex.format!(start_datetime, @time_format) <>
        " – " <> Timex.format!(end_datetime, @time_format)
    else
      Timex.format!(start_datetime, @datetime_format) <>
        " – " <> Timex.format!(end_datetime, @datetime_format)
    end
  end

  def datetime_span(start_datetime, end_datetime) do
    start_string = Timex.format!(start_datetime, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

    end_format =
      if Timex.to_date(start_datetime) == Timex.to_date(end_datetime) do
        "{h24}:{m}:{s}"
      else
        "{YYYY}-{0M}-{0D} {h24}:{m}:{s}"
      end

    end_string = Timex.format!(end_datetime, end_format)

    "#{start_string} – #{end_string} UTC"
  end
end