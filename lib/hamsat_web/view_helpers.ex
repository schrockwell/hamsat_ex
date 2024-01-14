defmodule HamsatWeb.ViewHelpers do
  alias Hamsat.Alerts.Pass
  alias Hamsat.Context
  alias Hamsat.Schemas.Alert

  @date_format "{YYYY}-{0M}-{0D}"
  @time_formats %{
    "12h" => "{h12}:{m}:{s} {AM}",
    "24h" => "{h24}:{m}:{s}"
  }
  @short_time_formats %{
    "12h" => "{h12}:{m} {AM}",
    "24h" => "{h24}:{m}"
  }
  @datetime_formats %{
    "12h" => @date_format <> " " <> @time_formats["12h"],
    "24h" => @date_format <> " " <> @time_formats["24h"]
  }

  def date(%Context{} = context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!(@date_format)
  end

  def time(%Context{} = context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!(@time_formats[context.time_format])
  end

  def short_time(%Context{} = context, utc_datetime) do
    utc_datetime
    |> normalize_datetime()
    |> Timex.to_datetime(context.timezone)
    |> Timex.format!(@short_time_formats[context.time_format])
  end

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

  def time_span(context, start_datetime, end_datetime) do
    start_datetime = start_datetime |> Timex.to_datetime("Etc/UTC") |> Timex.to_datetime(context.timezone)
    end_datetime = end_datetime |> Timex.to_datetime("Etc/UTC") |> Timex.to_datetime(context.timezone)

    if Timex.to_date(start_datetime) == Timex.to_date(end_datetime) do
      Timex.format!(start_datetime, @time_formats[context.time_format]) <>
        " – " <> Timex.format!(end_datetime, @time_formats[context.time_format])
    else
      Timex.format!(start_datetime, @datetime_formats[context.time_format]) <>
        " – " <> Timex.format!(end_datetime, @datetime_formats[context.time_format])
    end
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

  def timezone_name("Etc/UTC"), do: "UTC"

  def timezone_name(timezone) do
    datetime = DateTime.now!(timezone)
    offset = datetime.utc_offset + datetime.std_offset
    Hamsat.Util.format_offset(offset)
  end

  def subband_range(%{lower_mhz: mhz, upper_mhz: mhz}), do: "#{mhz(mhz, 3)} MHz"
  def subband_range(subband), do: "#{mhz(subband.lower_mhz, 3)} – #{mhz(subband.upper_mhz, 3)} MHz"

  def active_nav_item(path) do
    cond do
      Regex.match?(~r/^(\/sats)/, path) -> :sats
      Regex.match?(~r/^(\/alerts)/, path) -> :alerts
      Regex.match?(~r/^\/passes/, path) -> :passes
      Regex.match?(~r/^\/location/, path) -> :location
      Regex.match?(~r/^\/users\/settings/, path) -> :settings
      Regex.match?(~r/^\/users\/register/, path) -> :register
      Regex.match?(~r/^\/users\/log_in/, path) -> :log_in
      :else -> nil
    end
  end

  def alert_saved_by({[], 0}), do: "nobody"
  def alert_saved_by({[], 1}), do: "somebody"
  def alert_saved_by({[], _count}), do: "some people"
  def alert_saved_by({callsigns, 0}), do: Enum.join(callsigns, ", ")
  def alert_saved_by({callsigns, 1}), do: Enum.join(callsigns, ", ") <> ", and 1 other"
  def alert_saved_by({callsigns, count}), do: Enum.join(callsigns, ", ") <> ", and #{count} others"
end
