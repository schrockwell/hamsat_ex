defmodule HamsatWeb.ActivationComponents do
  @moduledoc """
  Entry points for upcoming-activation lists: the two-row table group used on
  the homepage and satellite detail page, plus the stacked card for narrow
  screens. Each renders as a stateful LiveComponent so the per-second clock
  tick only diffs the countdown text instead of re-sending every row.
  """

  use HamsatWeb, :component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.LiveComponents.ActivationCard
  alias HamsatWeb.LiveComponents.ActivationRows

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :show_sat, :boolean, default: true
  attr :show_match, :boolean, default: true
  # Distinguishes stateful child component IDs when the same alert is rendered
  # in more than one list on a page
  attr :id_suffix, :string, default: ""

  def activation_rows(assigns) do
    ~H"""
    <.live_component
      module={ActivationRows}
      id={"activation-rows#{@id_suffix}-#{@alert.id}"}
      alert={@alert}
      context={@context}
      now={@now}
      show_sat={@show_sat}
      show_match={@show_match}
      id_suffix={@id_suffix}
    />
    """
  end

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :show_sat, :boolean, default: true
  attr :show_match, :boolean, default: true
  attr :id_suffix, :string, default: ""

  def activation_card(assigns) do
    ~H"""
    <.live_component
      module={ActivationCard}
      id={"activation-card#{@id_suffix}-#{@alert.id}"}
      alert={@alert}
      context={@context}
      now={@now}
      show_sat={@show_sat}
      show_match={@show_match}
      id_suffix={@id_suffix}
    />
    """
  end

  @doc "\"145.945↑ SSB\", \"SSB\", or nil when the alert has neither"
  def alert_freq_mode(alert) do
    parts = Enum.reject([if(alert.mhz, do: mhz(alert)), alert.mode], &is_nil/1)
    if parts == [], do: nil, else: Enum.join(parts, " ")
  end

  # Kept as a function so the badge span stays on one line in the template —
  # a line break inside the span renders as visible whitespace in the label.
  # Color ranges match AlertComponents.match_percentage.
  def match_badge_class(total) do
    color =
      cond do
        total >= 0.75 -> "bg-emerald-100 text-emerald-600"
        total >= 0.25 -> "bg-amber-100 text-amber-600"
        true -> "bg-gray-200 text-gray-500"
      end

    [color, "text-xs font-semibold px-1.5 py-0.5 rounded ml-1.5"]
  end

  @doc "\"in 1:44\" / \"in 2d 2:25\" countdown until the activation's AOS"
  def countdown(%Alert{} = alert, now) do
    seconds = max(Timex.diff(alert.aos_at, now, :second), 0)

    days = div(seconds, 86_400)
    hours = div(rem(seconds, 86_400), 3600)
    minutes = div(rem(seconds, 3600), 60)
    minutes = if minutes < 10, do: "0#{minutes}", else: to_string(minutes)

    if days > 0 do
      "#{days}d #{hours}:#{minutes}"
    else
      "#{hours}:#{minutes}"
    end
  end

  @doc """
  "11:46 – 12:03", prefixed with a short weekday ("Mon 13:56 – 14:12") when
  the pass starts beyond today
  """
  def alert_time_span(context, alert) do
    aos_local = alert.aos_at |> Timex.to_datetime(context.timezone)

    prefix =
      if Timex.to_date(aos_local) == Timex.today(context.timezone) do
        ""
      else
        Timex.format!(aos_local, "{WDshort} ")
      end

    prefix <> short_time(context, alert.aos_at) <> " – " <> short_time(context, alert.los_at)
  end
end
