defmodule HamsatWeb.AlertsLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Chat
  alias Hamsat.Alerts.Match
  alias Hamsat.Context
  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.PassMatch
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.ChatMessage
  alias Hamsat.Schemas.Sat
  alias HamsatWeb.SatTracker
  alias HamsatWeb.LiveComponents.AlertSaver
  alias HamsatWeb.LiveComponents.PassTracker

  def mount(%{"id" => alert_id}, _session, socket) do
    alert = Alerts.get_alert!(socket.assigns.context, alert_id)

    pass_match =
      if socket.assigns.context.location do
        locations = [
          socket.assigns.context.location,
          %Coord{lat: alert.observer_lat, lon: alert.observer_lon}
        ]

        PassMatch.new(alert.sat, locations, alert.aos_at)
      end

    saved_by = Alerts.list_saved_callsigns(alert)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
      if alert.chat_enabled, do: Chat.subscribe(alert)
    end

    chat_messages = if alert.chat_enabled, do: Chat.list_messages(alert), else: []

    socket =
      socket
      |> assign(:now, DateTime.utc_now())
      |> assign(:page_title, "#{alert.callsign} on #{alert.sat.name}")
      |> assign(alert: alert, pass_match: pass_match, saved_by: saved_by)
      |> assign(:chat_messages, chat_messages)
      |> assign(:chat_empty?, chat_messages == [])
      |> assign(:chat_changeset, Chat.change_message())
      |> assign_tick()
      |> schedule_tick()

    {:ok, socket, temporary_assigns: [chat_messages: []]}
  end

  def handle_event("delete", _, socket) do
    if Alert.owned?(socket.assigns.alert, socket.assigns.context.user) do
      Alerts.delete_alert(socket.assigns.alert)

      {:noreply,
       socket
       |> put_flash(:info, "Activation deleted.")
       |> redirect(to: ~p"/alerts")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("send-chat-message", %{"chat_message" => params}, socket) do
    case Chat.send_message(socket.assigns.context.user, socket.assigns.alert, params) do
      {:ok, _message} ->
        # The message comes back to us (and everyone else) via PubSub
        {:noreply, assign(socket, :chat_changeset, Chat.change_message())}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :chat_changeset, changeset)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  def handle_info(:tick, socket) do
    socket =
      socket
      |> assign(now: DateTime.utc_now())
      |> assign_tick()
      |> schedule_tick()

    {:noreply, socket}
  end

  def handle_info({event, %{alert_id: id}}, %{assigns: %{alert: %{id: id}}} = socket)
      when event in [:alert_saved, :alert_unsaved] do
    socket =
      assign(socket,
        saved_by: Alerts.list_saved_callsigns(socket.assigns.alert),
        alert: Alerts.get_alert!(socket.assigns.context, id)
      )

    {:noreply, socket}
  end

  def handle_info({:chat_message, %ChatMessage{} = message}, socket) do
    {:noreply,
     socket
     |> update(:chat_messages, &(&1 ++ [message]))
     |> assign(:chat_empty?, false)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp schedule_tick(socket) do
    # Stop ticking once alert LOS has passed
    # if DateTime.compare(socket.assigns.alert.los_at, DateTime.utc_now()) == :gt do
    Process.send_after(self(), :tick, :timer.seconds(1))
    # end

    socket
  end

  # Position (0.0–1.0) of a moment within the pass, for the timeline bar
  defp marker_left(alert, datetime), do: "left: #{progress(alert, datetime) * 100}%"

  # When the visible window begins at rise (or ends at set) the emerald node
  # takes over the rise/set node rather than drawing two nodes on top of each other.
  # Fraction of the bar under which a visible-window node merges into the
  # rise/set node instead of drawing overlapping nodes and labels
  @node_merge_threshold 0.08

  defp separate_node?(alert, which), do: alert.is_workable? and not coincident?(alert, which)

  defp coincident?(%Alert{is_workable?: false}, _end), do: false
  defp coincident?(alert, :rise), do: progress(alert, alert.workable_start_at) < @node_merge_threshold
  defp coincident?(alert, :set), do: progress(alert, alert.workable_end_at) > 1.0 - @node_merge_threshold

  defp node_class(alert, which),
    do: if(coincident?(alert, which), do: "border-emerald-500", else: "border-gray-300")

  defp node_time_class(alert, which),
    do: if(coincident?(alert, which), do: "text-emerald-700", else: "text-gray-700")

  defp node_label(alert, :rise), do: if(coincident?(alert, :rise), do: "Rise · Visible", else: "Rise")
  defp node_label(alert, :set), do: if(coincident?(alert, :set), do: "End visible · Set", else: "Set")

  defp workable_segment_style(alert) do
    start = progress(alert, alert.workable_start_at)
    stop = progress(alert, alert.workable_end_at)
    "left: #{start * 100}%; width: #{(stop - start) * 100}%"
  end

  def assign_tick(socket) do
    alert = socket.assigns.alert
    now = socket.assigns.now
    progress = max(min(progress(alert, now), 1.0), 0.0)

    progression = Alert.progression(alert, now)
    events = Alert.events(alert, now)

    cursor_class =
      case progression do
        :upcoming -> "bg-gray-400"
        :passed -> "bg-gray-300"
        :workable -> "bg-emerald-500"
        _ -> "bg-gray-500"
      end

    my_sat_position =
      if socket.assigns.context.location do
        alert.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(socket.assigns.context.location), magnitude?: false)
      end

    activator_sat_position =
      if socket.assigns.context.location do
        alert.sat
        |> Sat.get_satrec()
        |> Satellite.current_position(Coord.to_observer(%Coord{lat: alert.observer_lat, lon: alert.observer_lon}),
          magnitude?: false
        )
      end

    assign(socket,
      activator_sat_position: activator_sat_position,
      chat_status: Chat.status(alert, now),
      cursor_class: cursor_class,
      cursor_style: "left: #{progress * 100}%",
      events: events,
      my_sat_position: my_sat_position,
      progression: progression,
      status: status(alert, progression, now)
    )
  end

  # The single status chip shown above the timeline: {label, timer, class}
  defp status(alert, progression, now) do
    gray = "border-gray-300 bg-gray-100 text-gray-700"

    case progression do
      :upcoming ->
        {"Upcoming", "rises in #{duration(now, alert.aos_at)}", gray}

      :before_workable ->
        {"In progress", "visible in #{duration(now, alert.workable_start_at)}", gray}

      :workable ->
        {"Visible", "for another #{duration(now, alert.workable_end_at)}",
         "border-emerald-500 bg-emerald-100 text-emerald-700"}

      :after_workable ->
        {"In progress", "sets in #{duration(now, alert.los_at)}", gray}

      :in_progress ->
        {"In progress", "sets in #{duration(now, alert.los_at)}", gray}

      :passed ->
        {"Passed", "#{Timex.from_now(alert.los_at, now)}", "border-gray-200 bg-gray-100 text-gray-400"}
    end
  end

  # "12m" until the chat window closes, never below 1m while open
  defp chat_closes_in(alert, now) do
    minutes = ceil(DateTime.diff(Chat.closes_at(alert), now) / 60)
    "#{max(minutes, 1)}m"
  end

  defp progress(alert, now) do
    duration = DateTime.diff(alert.los_at, alert.aos_at)
    after_aos = DateTime.diff(now, alert.aos_at)
    after_aos / duration
  end

  defp elevation_class(elevation) when elevation <= 0, do: "text-red-600"
  defp elevation_class(_), do: "text-gray-800"

  # "Sat Aug 23 · 11:46 – 12:03 EDT", in the viewer's timezone
  defp when_text(context, alert) do
    aos = Timex.to_datetime(alert.aos_at, context.timezone)
    los = Timex.to_datetime(alert.los_at, context.timezone)

    date = Timex.format!(aos, "{WDshort} {Mshort} {D}")
    zone = Timex.format!(aos, "{Zabbr}")

    "#{date} · #{short_time(context, aos)} – #{short_time(context, los)} #{zone}"
  end

  defp uplink_text(alert) do
    [mhz(alert, 3, nil), alert.mode]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> "–"
      text -> text
    end
  end

  defp match_tooltip(alert) do
    el_max = Match.el_max_points()

    "My elevation #{alert.match.my_el}/#{el_max} · #{alert.callsign} elevation #{alert.match.dx_el}/#{el_max} · Mode #{alert.match.mode}/#{Match.mode_max_points()}"
  end

  defp saved_by_count({callsigns, extra}), do: length(callsigns) + extra

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :position, :map, required: true
  attr :alert, Alert, required: true
  attr :now, DateTime, required: true
  attr :pass_plot, :any, default: nil
  attr :class, :string, default: nil

  defp station_tracker(assigns) do
    ~H"""
    <div class={["flex flex-col", @class]}>
      <div class="flex items-stretch bg-gray-50 border-b">
        <div class="flex-1 flex items-center px-6 py-2.5 text-xl font-semibold text-gray-700 whitespace-nowrap">
          <%= @title %>
        </div>
        <div class="flex items-baseline gap-2 px-4 py-2.5 border-l">
          <span class="uppercase text-sm tracking-wider text-gray-400">Az</span>
          <span class="text-xl text-gray-800 tabular-nums whitespace-nowrap">
            <%= deg(@position.azimuth_in_degrees) %>
          </span>
        </div>
        <div class="flex items-baseline gap-2 px-4 py-2.5 border-l">
          <span class="uppercase text-sm tracking-wider text-gray-400">El</span>
          <span class={["text-xl tabular-nums whitespace-nowrap", elevation_class(@position.elevation_in_degrees)]}>
            <%= deg(@position.elevation_in_degrees) %>
          </span>
        </div>
      </div>
      <div class="flex justify-center px-6 py-5">
        <div class="w-[80%]">
          <PassTracker.component id={@id} sat={@alert.sat} now={@now} pass_plot={@pass_plot} />
        </div>
      </div>
    </div>
    """
  end

  defp microblog_url_text(alert) do
    url = URI.encode(url(HamsatWeb.Endpoint, ~p"/alerts/#{alert.id}"))
    grids = alert_grids(alert)

    freq =
      case {alert.mhz, alert.mode} do
        {nil, nil} -> nil
        {_mhz, nil} -> "📻 #{mhz(alert)}"
        {nil, mode} -> "📻 #{mode}"
        {_mhz, mode} -> "📻 #{mhz(alert)} #{mode}"
      end

    comment =
      if alert.comment do
        "📢 #{alert.comment}"
      end

    utc_context = %Context{}

    [
      "🛰 #{alert.callsign} on #{alert.sat.name}",
      "⏰ #{date(utc_context, alert.aos_at)} from #{short_time(utc_context, alert.aos_at)}Z to #{short_time(utc_context, alert.los_at)}Z",
      "🗺 #{grids}",
      freq,
      comment,
      "👀 #{url}"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> URI.encode()
  end

  defp tweet_url(alert) do
    "https://twitter.com/intent/tweet?text=#{microblog_url_text(alert)}"
  end

  defp mastodon_url(alert) do
    "https://mastodonshare.com/?text=#{microblog_url_text(alert)}"
  end

  defp satmatch_url(context, alert) do
    satname = alert.sat.nasa_name
    obs1 = Grid.encode!({alert.observer_lat, alert.observer_lon}, 6)

    obs2 =
      if context.location,
        do: Grid.encode!(context.location, 6)

    # SatMatch searches for passes AFTER the specified datetime, so give it a grace
    # period to ensure that it finds the desired pass
    timestamp = alert.aos_at |> Timex.shift(minutes: -10) |> DateTime.to_iso8601()

    if obs1 != obs2 and obs2 != nil do
      "https://www.satmatch.com/satellite/#{satname}/obs1/#{obs1}/obs2/#{obs2}/pass/#{timestamp}"
    else
      "https://satmatch.com/satellite/#{satname}/obs1/#{obs1}/pass/#{timestamp}"
    end
  end

  defp activator_coord(alert) do
    %Coord{lat: alert.observer_lat, lon: alert.observer_lon}
  end
end
