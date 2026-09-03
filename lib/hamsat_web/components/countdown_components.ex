defmodule HamsatWeb.CountdownComponents do
  @moduledoc """
  Time displays that tick in the browser instead of on the server.

  A countdown is described by a list of *segments*, in chronological order.
  Each segment applies until its `:until` datetime (`nil` for the last one)
  and is either static text or a template whose `%s` is a duration to `:to`
  formatted in one of these styles:

    * `:countdown` - "1:44" / "2d 1:44", never negative
    * `:coarse` - `HamsatWeb.ViewHelpers.hms/2` with `coarse?: true`
    * `:hms` - `HamsatWeb.ViewHelpers.hms/2`
    * `:ago` - "just now" / "5 minutes ago" / "2 hours ago" / "3 days ago"
    * `:closes` - "2d" / "5h" / "12m", never below 1m

      [
        %{until: aos_at, template: "rises in %s", to: aos_at, style: :hms},
        %{until: los_at, template: "sets in %s", to: los_at, style: :hms},
        %{until: nil, template: "%s", to: los_at, style: :ago}
      ]

  The `Countdown` JS hook (`assets/js/countdown-hook.js`) keeps the text
  current and hides the element when the text is empty. The initial text is
  rendered here with the same rules. Keep the two in sync.
  """
  use Phoenix.Component

  alias HamsatWeb.ViewHelpers

  attr :id, :string, required: true
  attr :segments, :list, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def countdown(assigns) do
    text = countdown_text(assigns.segments, DateTime.utc_now())

    assigns =
      assign(assigns,
        text: text,
        segments_json: Jason.encode!(Enum.map(assigns.segments, &encode_segment/1))
      )

    ~H"""
    <span
      id={@id}
      phx-hook="Countdown"
      phx-update="ignore"
      data-segments={@segments_json}
      class={[@class, @text == "" && "hidden"]}
      {@rest}
    >
      <%= @text %>
    </span>
    """
  end

  attr :id, :string, required: true
  attr :start_at, DateTime, required: true
  attr :end_at, DateTime, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block

  @doc """
  An absolutely-positioned element that the `ProgressCursor` JS hook slides
  from `left: 0%` at `start_at` to `left: 100%` at `end_at`.
  """
  def progress_cursor(assigns) do
    progress = progress(assigns.start_at, assigns.end_at, DateTime.utc_now())
    assigns = assign(assigns, :style, "left: #{progress * 100}%")

    ~H"""
    <div
      id={@id}
      phx-hook="ProgressCursor"
      phx-update="ignore"
      data-start-at={DateTime.to_iso8601(@start_at)}
      data-end-at={DateTime.to_iso8601(@end_at)}
      style={@style}
      class={@class}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  The text a countdown shows at `now`.
  """
  def countdown_text(segments, now) do
    segment =
      Enum.find(segments, List.last(segments), fn segment ->
        segment.until == nil or DateTime.compare(segment.until, now) == :gt
      end)

    case segment do
      %{template: template, to: to, style: style} ->
        seconds = div(DateTime.diff(to, now, :millisecond), 1000)
        String.replace(template, "%s", format(style, seconds))

      %{text: text} ->
        text

      nil ->
        ""
    end
  end

  @doc """
  Formats a signed number of seconds in one of the countdown styles.
  """
  def format(:countdown, seconds) do
    seconds = max(seconds, 0)

    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)

    if days > 0 do
      "#{days}d #{hours}:#{pad(minutes)}"
    else
      "#{hours}:#{pad(minutes)}"
    end
  end

  def format(:coarse, seconds), do: ViewHelpers.hms(seconds, coarse?: true)

  def format(:hms, seconds), do: ViewHelpers.hms(seconds)

  def format(:ago, seconds) do
    seconds = max(-seconds, 0)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{plural(div(seconds, 60), "minute")} ago"
      seconds < 86_400 -> "#{plural(div(seconds, 3600), "hour")} ago"
      true -> "#{plural(div(seconds, 86_400), "day")} ago"
    end
  end

  def format(:closes, seconds) do
    minutes = max(ceil(seconds / 60), 1)

    cond do
      minutes > 24 * 60 -> "#{ceil(minutes / (24 * 60))}d"
      minutes > 60 -> "#{ceil(minutes / 60)}h"
      true -> "#{minutes}m"
    end
  end

  defp progress(start_at, end_at, now) do
    duration = DateTime.diff(end_at, start_at, :millisecond)
    elapsed = DateTime.diff(now, start_at, :millisecond)

    (elapsed / max(duration, 1)) |> max(0.0) |> min(1.0)
  end

  defp encode_segment(%{template: template, to: to, style: style} = segment) do
    %{until: iso(segment.until), template: template, to: iso(to), style: style}
  end

  defp encode_segment(%{text: text} = segment) do
    %{until: iso(segment.until), text: text}
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp pad(int) when int < 10, do: "0#{int}"
  defp pad(int), do: to_string(int)

  defp plural(1, unit), do: "1 #{unit}"
  defp plural(n, unit), do: "#{n} #{unit}s"
end
