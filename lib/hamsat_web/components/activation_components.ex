defmodule HamsatWeb.ActivationComponents do
  @moduledoc """
  Shared markup for upcoming-activation lists: the two-row table group used on
  the homepage and satellite detail page, plus the stacked card for narrow
  screens.
  """

  use HamsatWeb, :component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.LiveComponents.AlertSaver

  # A two-row group for one upcoming activation

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :show_sat, :boolean, default: true
  attr :show_match, :boolean, default: true
  # Distinguishes stateful child component IDs when the same alert is rendered
  # in more than one list on a page
  attr :id_suffix, :string, default: ""

  def activation_rows(assigns) do
    in_progress? = Alert.progression(assigns.alert, assigns.now) not in [:upcoming, :passed]

    assigns =
      assigns
      |> assign(:in_progress?, in_progress?)
      |> assign(:row1_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700 font-semibold", else: nil))
      |> assign(:row2_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700", else: "text-gray-500"))

    ~H"""
    <tr class={@row1_class}>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base">
        <%= if @in_progress? do %>
          now
        <% else %>
          <%= if @show_match and @alert.match do %>
            <span class={match_badge_class(@alert.match.total)}><%= pct(@alert.match.total) %></span>
          <% end %>
          in <%= countdown(@alert, @now) %>
        <% end %>
      </td>
      <%= if @show_sat do %>
        <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= @alert.sat.name %></td>
      <% end %>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= @alert.callsign %></td>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= alert_grids(@alert) %></td>
      <td class="px-1 py-1 border-b text-right align-middle" rowspan="2">
        <div class="flex gap-1.5 justify-end items-center">
          <%= if @alert.chat_enabled do %>
            <span title="Chat enabled">
              <Heroicons.LiveView.icon name="chat-bubble-left-right" type="mini" class="block h-4 w-4 text-gray-400" />
            </span>
          <% end %>
          <AlertSaver.component
            alert={@alert}
            context={@context}
            id={"alert-saver#{@id_suffix}-#{@alert.id}"}
            class="btn btn-default btn-sm border-gray-300 tabular-nums"
          />
          <.link
            navigate={~p"/alerts/#{@alert.id}"}
            class="btn btn-sm bg-sky-600 hover:bg-sky-700 text-white border-transparent"
            title="Track this pass"
          >
            Track
          </.link>
        </div>
      </td>
    </tr>
    <tr class={@row2_class}>
      <td class="pt-0.5 pb-3.5 px-1 border-b whitespace-nowrap text-[13px]"><%= alert_time_span(@context, @alert) %></td>
      <td class="pt-0.5 pb-3.5 px-1 border-b whitespace-nowrap text-[13px]">
        <%= if @alert.mhz do %>
          <%= mhz(@alert) %>
        <% end %>
        <%= @alert.mode %>
      </td>
      <td colspan={if @show_sat, do: 2, else: 1} class="pt-0.5 pb-3.5 px-1 border-b text-[13px] italic">
        <%= if @alert.comment do %>
          “<%= @alert.comment %>”
        <% end %>
      </td>
    </tr>
    """
  end

  # Stacked-card version of an activation for narrow screens, where the
  # multi-column table cannot fit without horizontal scrolling

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :show_sat, :boolean, default: true
  attr :show_match, :boolean, default: true
  attr :id_suffix, :string, default: ""

  def activation_card(assigns) do
    in_progress? = Alert.progression(assigns.alert, assigns.now) not in [:upcoming, :passed]

    assigns =
      assigns
      |> assign(:in_progress?, in_progress?)
      |> assign(:card_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700", else: nil))
      |> assign(:line1_class, if(in_progress?, do: "font-semibold", else: nil))
      |> assign(:detail_class, if(in_progress?, do: "text-emerald-700", else: "text-gray-500"))

    ~H"""
    <div class={["py-3 -mx-3 px-3 border-b slashed-zero", @card_class]}>
      <div class="flex items-center justify-between gap-3">
        <div class={["text-base whitespace-nowrap", @line1_class]}>
          <%= if @in_progress? do %>
            now
          <% else %>
            <%= if @show_match and @alert.match do %>
              <span class={match_badge_class(@alert.match.total)}><%= pct(@alert.match.total) %></span>
            <% end %>
            in <%= countdown(@alert, @now) %>
          <% end %>
        </div>
        <div class="flex gap-1.5 items-center shrink-0">
          <%= if @alert.chat_enabled do %>
            <span title="Chat enabled">
              <Heroicons.LiveView.icon name="chat-bubble-left-right" type="mini" class="block h-4 w-4 text-gray-400" />
            </span>
          <% end %>
          <AlertSaver.component
            alert={@alert}
            context={@context}
            id={"alert-saver-sm#{@id_suffix}-#{@alert.id}"}
            class="btn btn-default btn-sm border-gray-300 tabular-nums"
          />
          <.link
            navigate={~p"/alerts/#{@alert.id}"}
            class="btn btn-sm bg-sky-600 hover:bg-sky-700 text-white border-transparent"
            title="Track this pass"
          >
            Track
          </.link>
        </div>
      </div>
      <div class={["text-base mt-0.5", @line1_class]}>
        <%= if @show_sat do %>
          <%= @alert.sat.name %> ·
        <% end %>
        <%= @alert.callsign %> · <%= alert_grids(@alert) %>
      </div>
      <div class={["text-[13px] mt-0.5", @detail_class]}>
        <%= alert_time_span(@context, @alert) %>
        <%= if alert_freq_mode(@alert) do %>
          · <%= alert_freq_mode(@alert) %>
        <% end %>
      </div>
      <%= if @alert.comment do %>
        <div class={["text-[13px] italic", @detail_class]}>“<%= @alert.comment %>”</div>
      <% end %>
    </div>
    """
  end

  # "145.945↑ SSB", "SSB", or nil when the alert has neither
  defp alert_freq_mode(alert) do
    parts = Enum.reject([if(alert.mhz, do: mhz(alert)), alert.mode], &is_nil/1)
    if parts == [], do: nil, else: Enum.join(parts, " ")
  end

  # Kept as a function so the badge span stays on one line in the template —
  # a line break inside the span renders as visible whitespace in the label.
  # Color ranges match AlertComponents.match_percentage.
  defp match_badge_class(total) do
    color =
      cond do
        total >= 0.75 -> "bg-emerald-100 text-emerald-600"
        total >= 0.25 -> "bg-amber-100 text-amber-600"
        true -> "bg-gray-200 text-gray-500"
      end

    [color, "text-xs font-semibold px-1.5 py-0.5 rounded mr-1.5"]
  end

  # "in 1:44" / "in 2d 2:25" countdown until the activation's AOS
  defp countdown(%Alert{} = alert, now) do
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

  # "11:46 – 12:03", prefixed with a short weekday ("Mon 13:56 – 14:12") when
  # the pass starts beyond today
  defp alert_time_span(context, alert) do
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
