defmodule HamsatWeb.SatsLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Coord
  alias Hamsat.Passes
  alias Hamsat.PassPlot
  alias Hamsat.Satellites
  alias Hamsat.Satellites.PositionServer
  alias Hamsat.Schemas.Sat

  alias HamsatWeb.Alerts.Components.AlertTableRow
  alias HamsatWeb.LocationSetter
  alias HamsatWeb.PassesLive.Components.PassTableRow
  alias HamsatWeb.SatTracker

  on_mount HamsatWeb.Live.NowTicker

  def mount(%{"number" => number}, _session, socket) do
    sat = Satellites.get_satellite_by_number!(number)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "satellite_positions")
    end

    socket =
      socket
      |> assign(:page_title, sat.name)
      |> assign(sat: sat)
      |> assign_alerts()
      |> assign_passes()
      |> assign_sat_positions()

    {:ok, assign(socket, sat: sat)}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    {:noreply,
     assign(
       socket,
       alerts: Alerts.patch_alerts(socket.assigns.alerts, socket.assigns.context, message)
     )}
  end

  def handle_info({:satellite_positions, positions}, socket) do
    {:noreply, assign(socket, sat_positions: Enum.filter(positions, &(&1.sat_id == socket.assigns.sat.id)))}
  end

  defp assign_alerts(socket) do
    assign(
      socket,
      :alerts,
      Alerts.list_alerts(socket.assigns.context, sat_id: socket.assigns.sat.id, date: :upcoming)
    )
  end

  defp assign_passes(socket) do
    if socket.assigns.context.location do
      assign(
        socket,
        :passes,
        Passes.list_all_passes(socket.assigns.context, [socket.assigns.sat], ending: Timex.shift(Timex.now(), days: 1))
      )
    else
      assign(socket, :passes, [])
    end
  end

  defp assign_sat_positions(socket) do
    assign(socket,
      sat_positions: Enum.filter(PositionServer.get_sat_positions(), &(&1.sat_id == socket.assigns.sat.id))
    )
  end

  defp transponder_mode(:linear), do: "Linear Transponder (Inverting)"
  defp transponder_mode(:linear_non_inv), do: "Linear Transponder (Non-Inverting)"
  defp transponder_mode(:fm), do: "FM Transponder"
  defp transponder_mode(:digital), do: "Digital Transponder"
  defp transponder_mode(:cw_beacon), do: "CW Beacon"
  defp transponder_mode(:telemetry), do: "Telemetry"
  defp transponder_mode(other), do: to_string(other)

  defp transponder_status_badge(%{status: :active} = assigns) do
    ~H"""
    <span class="bg-green-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="check" type="mini" class="h-4 w-4" />Active
    </span>
    """
  end

  defp transponder_status_badge(%{status: :inactive} = assigns) do
    ~H"""
    <span class="bg-red-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="x-mark" type="mini" class="h-4 w-4" /> Inactive
    </span>
    """
  end

  defp transponder_status_badge(%{status: :problems} = assigns) do
    ~H"""
    <span class="bg-orange-500 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="exclamation-triangle" type="mini" class="h-4 w-4" />Problems
    </span>
    """
  end

  defp transponder_status_badge(%{status: :conflicting} = assigns) do
    ~H"""
    <span class="bg-orange-500 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="question-mark-circle" type="mini" class="h-4 w-4" />Conflicting Reports
    </span>
    """
  end

  defp transponder_status_badge(%{status: :unknown} = assigns) do
    ~H"""
    <span class="bg-red-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="question-mark-circle" type="mini" class="h-4 w-4" /> Unknown
    </span>
    """
  end

  defp transponder_panel(assigns) do
    ~H"""
    <div class="border rounded p-4 mb-4 space-y-4">
      <div class="flex items-center justify-between">
        <div class="text-lg"><%= transponder_mode(@transponder.mode) %></div>
        <div><.transponder_status_badge status={@transponder.status} /></div>
      </div>
      <div class="flex">
        <%= if @transponder.downlink do %>
          <div class="flex-1">
            <div class="text-xl">
              <%= subband_range(@transponder.downlink) %>
            </div>
            <div>Downlink</div>
          </div>
        <% end %>
        <%= if @transponder.uplink do %>
          <div class="flex-1">
            <div class="text-xl">
              <%= subband_range(@transponder.uplink) %>
            </div>
            <div>Uplink</div>
          </div>
        <% end %>
      </div>
      <%= if @transponder.notes do %>
        <div><%= @transponder.notes %></div>
      <% end %>
    </div>
    """
  end
end
