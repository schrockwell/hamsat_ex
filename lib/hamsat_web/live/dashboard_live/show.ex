defmodule HamsatWeb.DashboardLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts.User
  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Context
  alias Hamsat.Grid
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Schemas.Alert

  alias HamsatWeb.LiveComponents.AlertSaver
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

  # A two-row group for one upcoming activation

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true

  defp activation_rows(assigns) do
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
          <%= if @alert.match do %>
            <span class={match_badge_class(@alert.match.total)}><%= pct(@alert.match.total) %></span>
          <% end %>
          in <%= countdown(@alert, @now) %>
        <% end %>
      </td>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= @alert.sat.name %></td>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= @alert.callsign %></td>
      <td class="pt-3.5 pb-0.5 px-1 whitespace-nowrap text-base"><%= alert_grids(@alert) %></td>
      <td class="px-1 py-1 border-b text-right align-middle" rowspan="2">
        <div class="flex gap-1.5 justify-end items-center">
          <AlertSaver.component
            alert={@alert}
            context={@context}
            id={"alert-saver-#{@alert.id}"}
            class="btn btn-default btn-sm border-gray-300 tabular-nums"
          />
          <.link navigate={~p"/alerts/#{@alert.id}"} class="btn btn-default btn-sm border-gray-300" title="Track this pass">
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
      <td colspan="2" class="pt-0.5 pb-3.5 px-1 border-b text-[13px] italic">
        <%= if @alert.comment do %>
          “<%= @alert.comment %>”
        <% end %>
      </td>
    </tr>
    """
  end

  defp upcoming_feed_url(%Context{user: :guest}), do: url(~p"/feeds/upcoming_alerts")
  defp upcoming_feed_url(%Context{user: %User{feed_key: feed_key}}), do: url(~p"/feeds/upcoming_alerts/#{feed_key}")

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
