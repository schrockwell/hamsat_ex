defmodule HamsatWeb.SatsLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.SatComponents

  alias Hamsat.Satellites

  @sparkline_days 30

  def mount(_params, _session, socket) do
    all_sats = Satellites.list_satellites_and_stats()
    activation_days = Satellites.recent_activation_days()
    last_activations = Satellites.last_activation_dates()

    {:ok,
     assign(socket,
       page_title: "Satellites",
       all_sats: all_sats,
       activation_days: activation_days,
       last_activations: last_activations
     )}
  end

  def handle_params(params, _url, socket) do
    query = to_string(params["q"])

    sats =
      if query == "" do
        socket.assigns.all_sats
      else
        filter_sats(socket.assigns.all_sats, query)
      end

    {active, inactive} = Enum.split_with(sats, & &1.is_popular)
    active = Enum.sort_by(active, &{-&1.recent_activation_count, &1.name})
    inactive = sort_inactive(inactive, socket.assigns.last_activations)

    {:noreply, assign(socket, query: query, active_sats: active, inactive_sats: inactive)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/sats?q=#{query}")}
  end

  defp filter_sats(sats, query) do
    Enum.filter(sats, fn sat ->
      Enum.any?([sat.name | sat.aliases], fn name ->
        String.contains?(String.downcase(name), String.downcase(query))
      end)
    end)
  end

  # Most recently activated first; never-activated sats at the bottom (alphabetical)
  defp sort_inactive(sats, last_activations) do
    Enum.sort_by(sats, fn sat ->
      case last_activations[sat.id] do
        nil -> {1, nil, sat.name}
        last_at -> {0, DateTime.to_unix(last_at) * -1, sat.name}
      end
    end)
  end

  defp alias_text(sat), do: Enum.join(sat.aliases, " / ")

  # One bar per day for the past 30 days, oldest first. Height and shade scale
  # with the day's activation count relative to the satellite's busiest day.
  defp sparkline_bars(activation_days, sat) do
    days = activation_days[sat.id] || %{}
    today = Date.utc_today()

    counts =
      for offset <- (@sparkline_days - 1)..0//-1 do
        Map.get(days, Date.to_iso8601(Date.add(today, -offset)), 0)
      end

    max = max(1, Enum.max(counts))

    for count <- counts do
      ratio = count / max

      {class, height} =
        cond do
          count == 0 -> {"bg-emerald-100", 2}
          ratio > 0.75 -> {"bg-emerald-500", 4 + round(24 * ratio)}
          ratio > 0.5 -> {"bg-emerald-400", 4 + round(24 * ratio)}
          ratio > 0.25 -> {"bg-emerald-300", 4 + round(24 * ratio)}
          true -> {"bg-emerald-200", 4 + round(24 * ratio)}
        end

      {class, height}
    end
  end

  defp last_activation_text(last_activations, context, sat) do
    case last_activations[sat.id] do
      nil ->
        "never"

      aos_at ->
        aos_at
        |> Timex.to_datetime(context.timezone)
        |> Timex.format!("{Mshort} {D}, {YYYY}")
    end
  end
end
