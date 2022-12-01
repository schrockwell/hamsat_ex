defmodule HamsatWeb.ViewHelpers do
  alias Hamsat.Alerts.Pass
  alias Hamsat.Context
  alias Hamsat.Schemas.Alert

  @date_format "{YYYY}-{0M}-{0D}"
  @time_format "{h24}:{m}:{s}"
  @short_time_format "{h24}:{m}"
  @datetime_format @date_format <> " " <> @time_format

  def date(context_or_timezone, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(timezone(context_or_timezone))
    |> Timex.format!(@date_format)
  end

  def time(context_or_timezone, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(timezone(context_or_timezone))
    |> Timex.format!(@time_format)
  end

  def short_time(context_or_timezone, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(timezone(context_or_timezone))
    |> Timex.format!(@short_time_format)
  end

  defp timezone(:utc), do: "Etc/UTC"
  defp timezone(%Context{timezone: timezone}), do: timezone

  defp normalize_datetime(%DateTime{} = datetime), do: datetime
  defp normalize_datetime(erl_datetime), do: Hamsat.Util.erl_to_utc_datetime(erl_datetime)

  def pass_duration(%Pass{} = pass) do
    duration(pass.info.aos.datetime, pass.info.los.datetime)
  end

  def duration(start_time, end_time) do
    end_time
    |> Timex.diff(start_time, :second)
    |> hms()
  end

  def hms(seconds, opts \\ []) do
    coarse? = Keyword.get(opts, :coarse?, false)

    sign = if seconds < 0, do: "-", else: ""
    seconds = abs(seconds)

    days = floor(seconds / 86400)
    seconds = seconds - days * 86400

    hours = floor(seconds / 3600)
    seconds = seconds - hours * 3600

    minutes = floor(seconds / 60)
    seconds = seconds - minutes * 60

    case {coarse?, days, hours, minutes, seconds} do
      {_coarse?, 0, 0, 0, s} -> "#{sign}0:#{zero_pad(s)}"
      {_coarse?, 0, 0, m, s} -> "#{sign}#{m}:#{zero_pad(s)}"
      {false, 0, h, m, s} -> "#{sign}#{h}:#{zero_pad(m)}:#{zero_pad(s)}"
      {true, 0, h, m, _s} -> "#{sign}#{h}:#{zero_pad(m)}h"
      {false, d, h, m, s} -> "#{sign}#{d}d #{h}:#{zero_pad(m)}:#{zero_pad(s)}"
      {true, d, h, m, _s} -> "#{sign}#{d}d #{h}:#{zero_pad(m)}h"
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

  def pass_max_direction(%Pass{} = pass) do
    cardinal_direction(pass.info.max.azimuth_in_degrees)
  end

  def pass_los_direction(%Pass{} = pass) do
    cardinal_direction(pass.info.los.azimuth_in_degrees)
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

  def mhz(float, precision \\ 3, default \\ "–")

  def mhz(%Alert{mhz: nil}, precision, default) do
    mhz(nil, precision, default)
  end

  def mhz(%Alert{mhz: alert_mhz, mhz_direction: alert_direction}, precision, default) do
    "#{mhz(alert_mhz, precision, default)}#{direction(alert_direction)}"
  end

  def mhz(nil, _, default), do: default

  def mhz(float, precision, _default) do
    :io_lib.format("~.#{precision}f", [float])
  end

  def alert_next_workable_in(now, alert) do
    case Alert.next_event(alert, now) do
      {:workable, :start, seconds} -> "in #{hms(seconds, coarse?: true)}"
      {:workable, :end, seconds} -> "for #{hms(seconds, coarse?: true)}"
      _ -> "–"
    end
  end

  def pass_next_event_in(now, pass) do
    case Pass.next_event(pass, now) do
      {:aos, duration} -> "AOS in #{hms(duration, coarse?: true)}"
      {:los, duration} -> "LOS in #{hms(duration, coarse?: true)}"
      :never -> "–"
    end
  end

  def alert_grids(%Alert{} = alert) do
    Enum.join(alert.grids, "/")
  end

  def pluralized_count([_], singular, _plural), do: "1 #{singular}"
  def pluralized_count(1, singular, _plural), do: "1 #{singular}"

  def pluralized_count(list, _singular, plural) when is_list(list),
    do: "#{length(list)} #{plural}"

  def pluralized_count(count, _singular, plural) when is_integer(count),
    do: "#{count} #{plural}"

  def password_requirements do
    "Password must be between 8 and 72 characters."
  end

  def deg(float, decimals \\ 0) do
    :erlang.float_to_binary(float, decimals: decimals) <> "°"
  end

  def pct(number, decimals \\ 0)

  def pct(float, decimals) when is_float(float) do
    :erlang.float_to_binary(float * 100, decimals: decimals) <> "%"
  end

  def pct(int, decimals) when is_integer(int) do
    pct(int / 100, decimals)
  end

  def direction(:up), do: "↑"
  def direction(:down), do: "↓"
end
