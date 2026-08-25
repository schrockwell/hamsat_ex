defmodule HamsatWeb.LiveComponents.ActivationRows do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.ActivationComponents
  alias HamsatWeb.LiveComponents.AlertSaver
  alias HamsatWeb.SatComponents
  alias Phoenix.LiveView.JS

  # `now` is deliberately derived into assigns instead of being assigned
  # itself, so the per-second clock tick only diffs the countdown text rather
  # than re-sending the whole group over the wire.
  def update(assigns, socket) do
    {now, assigns} = Map.pop!(assigns, :now)
    in_progress? = Alert.progression(assigns.alert, now) not in [:upcoming, :passed]

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:in_progress?, in_progress?)
     |> assign(:row1_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700 font-semibold", else: nil))
     |> assign(:row2_class, if(in_progress?, do: "bg-emerald-100 text-emerald-700", else: "text-gray-500"))
     |> assign(:countdown, if(in_progress?, do: nil, else: ActivationComponents.countdown(assigns.alert, now)))
     |> assign(:time_span, ActivationComponents.alert_time_span(assigns.context, assigns.alert))}
  end

  def render(assigns) do
    ~H"""
    <tbody phx-click={JS.navigate(~p"/alerts/#{@alert.id}")} class="cursor-pointer hover:bg-gray-50" title="Track this pass">
      <tr class={@row1_class}>
        <td class="py-1 pr-1 border-b align-middle" rowspan="2">
          <SatComponents.mini_polar_plot coords={@alert.my_plot_coords} />
        </td>
        <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base">
          <%= if @in_progress? do %>
            now
          <% else %>
            in <%= @countdown %>
            <%= if @show_match and @alert.match do %>
              <span class={ActivationComponents.match_badge_class(@alert.match.total)}><%= pct(@alert.match.total) %></span>
            <% end %>
          <% end %>
        </td>
        <%= if @show_sat do %>
          <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base">
            <button
              type="button"
              phx-click={JS.navigate(~p"/sats/#{@alert.sat.number}")}
              title="Satellite details"
              class="link"
            >
              <%= @alert.sat.name %>
            </button>
          </td>
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
            <Heroicons.LiveView.icon name="chevron-right" type="mini" class="h-5 w-5 text-gray-400" />
          </div>
        </td>
      </tr>
      <tr class={@row2_class}>
        <td class="pt-0.5 pb-3.5 px-1 border-b whitespace-nowrap text-[13px]">
          <%= @time_span %>
        </td>
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
    </tbody>
    """
  end
end
