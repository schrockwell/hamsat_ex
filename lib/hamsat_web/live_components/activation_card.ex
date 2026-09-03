defmodule HamsatWeb.LiveComponents.ActivationCard do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.ActivationComponents
  alias HamsatWeb.LiveComponents.AlertSaver
  alias HamsatWeb.SatComponents
  alias Phoenix.LiveView.JS

  # See ActivationRows for why `now` is derived instead of assigned
  def update(assigns, socket) do
    {now, assigns} = Map.pop!(assigns, :now)
    in_progress? = Alert.progression(assigns.alert, now) not in [:upcoming, :passed]

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:in_progress?, in_progress?)
     |> assign(:card_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700", else: nil))
     |> assign(:line1_class, if(in_progress?, do: "font-semibold", else: nil))
     |> assign(:detail_class, if(in_progress?, do: "text-emerald-700", else: "text-gray-500"))
     |> assign(:time_span, ActivationComponents.alert_time_span(assigns.context, assigns.alert))}
  end

  def render(assigns) do
    ~H"""
    <div
      phx-click={JS.navigate(~p"/alerts/#{@alert.id}")}
      class={["py-3 -mx-3 px-3 border-b slashed-zero cursor-pointer flex items-center justify-between gap-3", @card_class]}
      title="Track this pass"
    >
      <div class="flex items-center gap-3 min-w-0">
        <SatComponents.mini_polar_plot coords={@alert.my_plot_coords} class="h-10 w-10 shrink-0" />
        <div class="min-w-0">
          <div class={["text-base whitespace-nowrap", @line1_class]}>
            <%= if @in_progress? do %>
              <span class="bg-red-600 text-white text-xs font-bold uppercase tracking-wide px-2 py-0.5 rounded">
                Now
              </span>
            <% else %>
              in
              <.countdown
                id={"activation-card-countdown#{@id_suffix}-#{@alert.id}"}
                segments={ActivationComponents.countdown_segments(@alert)}
              />
              <%= if @show_match and @alert.match do %>
                <span class={ActivationComponents.match_badge_class(@alert.match.total)}>
                  <%= pct(@alert.match.total) %>
                </span>
              <% end %>
            <% end %>
          </div>
          <div class={["text-base mt-0.5", @line1_class]}>
            <%= if @show_sat do %>
              <button
                type="button"
                phx-click={JS.navigate(~p"/sats/#{@alert.sat.number}")}
                title="Satellite details"
                class="link"
              >
                <%= @alert.sat.name %>
              </button>
              ·
            <% end %>
            <%= @alert.callsign %> · <%= alert_grids(@alert) %>
          </div>
          <div class={["text-[13px] mt-0.5", @detail_class]}>
            <%= @time_span %>
            <%= if ActivationComponents.alert_freq_mode(@alert) do %>
              · <%= ActivationComponents.alert_freq_mode(@alert) %>
            <% end %>
          </div>
          <%= if @alert.comment do %>
            <div class={["text-[13px] italic", @detail_class]}>“<%= @alert.comment %>”</div>
          <% end %>
        </div>
      </div>
      <div class="flex gap-1.5 items-center shrink-0">
        <%= if @alert.chat_enabled do %>
          <span title="Chat messages" class="inline-flex items-center gap-1 text-sm text-gray-400 tabular-nums">
            <Heroicons.LiveView.icon name="chat-bubble-left-right" type="mini" class="block h-4 w-4" />
            <%= @alert.chat_message_count %>
          </span>
        <% end %>
        <AlertSaver.component
          alert={@alert}
          context={@context}
          id={"alert-saver-sm#{@id_suffix}-#{@alert.id}"}
          class="btn btn-default btn-sm border-gray-300 tabular-nums"
        />
        <Heroicons.LiveView.icon name="chevron-right" type="mini" class="h-5 w-5 text-gray-400" />
      </div>
    </div>
    """
  end
end
