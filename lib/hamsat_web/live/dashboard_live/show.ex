defmodule HamsatWeb.DashboardLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts.User
  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Context
  alias Hamsat.Grid
  alias Hamsat.Passes
  alias Hamsat.Satellites

  import HamsatWeb.ActivationComponents

  alias HamsatWeb.SatComponents

  on_mount HamsatWeb.Live.NowTicker

  @reload_alerts_interval :timer.minutes(1)
  @reload_passes_interval :timer.minutes(15)
  @quiet_pass_hours 6
  @max_quiet_passes 30

  def mount(_params, _session, socket) do
    effective_context = Context.effective(socket.assigns.context)

    socket =
      socket
      |> assign(
        page_title: "Home",
        effective_context: effective_context,
        grid_label: Grid.encode!(effective_context.location, 4),
        quiet_passes: [],
        passes_loading?: true,
        show_rss_feed: false
      )
      |> assign_upcoming_alerts()

    socket =
      if connected?(socket) do
        Process.flag(:trap_exit, true)
        Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
        Process.send_after(self(), :reload_alerts, @reload_alerts_interval)
        Process.send_after(self(), :reload_passes, @reload_passes_interval)
        start_loading_quiet_passes(socket)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("toggle-rss-feed", _, socket) do
    {:noreply, assign(socket, show_rss_feed: !socket.assigns.show_rss_feed)}
  end

  def handle_info(:reload_alerts, socket) do
    Process.send_after(self(), :reload_alerts, @reload_alerts_interval)

    {:noreply,
     socket
     |> assign_upcoming_alerts()
     |> purge_passed_quiet_passes()}
  end

  def handle_info(:reload_passes, socket) do
    Process.send_after(self(), :reload_passes, @reload_passes_interval)
    {:noreply, start_loading_quiet_passes(socket)}
  end

  def handle_info({:quiet_passes_loaded, passes}, socket) do
    quiet_passes =
      passes
      |> Enum.filter(&(&1.alerts == []))
      |> Enum.take(@max_quiet_passes)

    {:noreply, assign(socket, quiet_passes: quiet_passes, passes_loading?: false)}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    {:noreply,
     assign(socket,
       visible_alerts: Alerts.patch_alerts(socket.assigns.visible_alerts, socket.assigns.context, message)
     )}
  end

  def handle_info({:EXIT, _, :normal}, socket), do: {:noreply, socket}

  def handle_info({:EXIT, task_pid, _reason}, %{assigns: %{passes_task_pid: task_pid}} = socket) do
    {:noreply, assign(socket, passes_loading?: false)}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp assign_upcoming_alerts(socket) do
    alerts = Alerts.list_alerts(socket.assigns.effective_context, date: :upcoming)
    {visible, not_visible} = Enum.split_with(alerts, & &1.is_workable?)

    assign(socket,
      visible_alerts: visible,
      visible_count: length(visible),
      not_visible_count: length(not_visible)
    )
  end

  defp start_loading_quiet_passes(socket) do
    parent = self()
    context = socket.assigns.effective_context
    sats = Satellites.list_in_orbit_satellites()
    ending = Timex.shift(DateTime.utc_now(), hours: @quiet_pass_hours)

    {:ok, task_pid} =
      Task.start_link(fn ->
        send(parent, {:quiet_passes_loaded, Passes.list_all_passes(context, sats, ending: ending)})
      end)

    assign(socket, passes_loading?: true, passes_task_pid: task_pid)
  end

  defp purge_passed_quiet_passes(socket) do
    quiet_passes =
      Enum.reject(socket.assigns.quiet_passes, &(Pass.progression(&1, socket.assigns.now) == :passed))

    assign(socket, quiet_passes: quiet_passes)
  end

  defp upcoming_feed_url(%Context{user: :guest}), do: url(~p"/feeds/upcoming_alerts")
  defp upcoming_feed_url(%Context{user: %User{feed_key: feed_key}}), do: url(~p"/feeds/upcoming_alerts/#{feed_key}")
end
