defmodule HamsatWeb.DashboardLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts.User
  alias Hamsat.Alerts
  alias Hamsat.Context
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Satellites.PositionServer

  alias HamsatWeb.DashboardLive.Components.AlertsList
  alias HamsatWeb.SatTracker

  on_mount HamsatWeb.Live.NowTicker

  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_reload_alerts()
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "satellite_positions")
    end

    {:ok,
     socket
     |> assign_defaults()
     |> assign_upcoming_alerts()
     |> assign_upcoming_alert_count()
     |> assign(sat_positions: PositionServer.get_sat_positions())}
  end

  def handle_event("toggle-rss-feed", _, socket) do
    {:noreply, assign(socket, show_rss_feed: !socket.assigns.show_rss_feed)}
  end

  def handle_event("sat-clicked", %{"sat_id" => id}, socket) do
    detail_sat = Satellites.get_satellite!(id)

    passes =
      if socket.assigns.context.location do
        Passes.list_passes(socket.assigns.context, detail_sat, ending: Timex.shift(DateTime.utc_now(), hours: 24))
      else
        []
      end

    {:noreply,
     assign(socket,
       detail_sat: detail_sat,
       detail_sat_passes: passes,
       sat_positions: amend_selected_sat(socket.assigns.sat_positions, detail_sat)
     )}
  end

  def handle_info(:reload_alerts, socket) do
    schedule_reload_alerts()

    {:noreply,
     socket
     |> assign_upcoming_alerts()}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    socket =
      assign(socket,
        upcoming_alerts: Alerts.patch_alerts(socket.assigns.upcoming_alerts, socket.assigns.context, message)
      )

    {:noreply, socket}
  end

  def handle_info({:satellite_positions, positions}, socket) do
    socket = assign(socket, sat_positions: amend_selected_sat(positions, socket.assigns.detail_sat))

    {:noreply, socket}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_defaults(socket) do
    assign(socket,
      page_title: "Home",
      sat_positions: [],
      show_rss_feed: false,
      detail_sat: nil,
      detail_sat_passes: []
    )
  end

  defp assign_upcoming_alerts(socket) do
    assign(
      socket,
      upcoming_alerts:
        Alerts.list_alerts(socket.assigns.context,
          date: :upcoming,
          limit: 25
        )
    )
  end

  defp assign_upcoming_alert_count(socket) do
    assign(socket, :upcoming_alert_count, Alerts.count_alerts(socket.assigns.context, date: :upcoming))
  end

  defp schedule_reload_alerts do
    Process.send_after(self(), :reload_alerts, :timer.minutes(1))
  end

  defp upcoming_feed_url(%Context{user: :guest}), do: url(~p"/feeds/upcoming_alerts")
  defp upcoming_feed_url(%Context{user: %User{feed_key: feed_key}}), do: url(~p"/feeds/upcoming_alerts/#{feed_key}")

  defp amend_selected_sat(sat_positions, nil), do: sat_positions

  defp amend_selected_sat(sat_positions, detail_sat) do
    Enum.map(sat_positions, fn pos ->
      Map.put(pos, :selected, pos.sat_id == detail_sat.id)
    end)
  end
end
