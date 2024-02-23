defmodule HamsatWeb.PassesLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts.Pass
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Util
  alias HamsatWeb.PassesLive.Components.PassTableRow
  alias HamsatWeb.LocationSetter

  on_mount HamsatWeb.Live.NowTicker

  @reload_passes_interval :timer.minutes(15)

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_defaults()
      |> assign_sats()
      |> assign_pass_filter_changeset()
      |> assign_results_description()

    if connected?(socket) do
      Process.flag(:trap_exit, true)
      Process.send_after(self(), :reload_passes, @reload_passes_interval)
    end

    {:ok, socket}
  end

  def handle_params(%{"date" => date}, _uri, socket) do
    socket =
      case Date.from_iso8601(date) do
        {:ok, date} -> assign(socket, date: date)
        {:error, _} -> assign(socket, date: Timex.today(socket.assigns.context.timezone))
      end

    {:noreply,
     socket
     |> assign(
       duration: :browse,
       can_load_more?: false,
       passes: [],
       passes_calculated_until: nil
     )
     |> maybe_append_upcoming_passes()}
  end

  def handle_params(_, _uri, socket) do
    {:noreply,
     socket
     |> assign(
       duration: :upcoming,
       hours: 6,
       date: nil,
       can_load_more?: true,
       passes: [],
       passes_calculated_until: nil
     )
     |> maybe_append_upcoming_passes()}
  end

  defp assign_defaults(socket) do
    assign(socket,
      loading?: true,
      failed?: false,
      needs_location?: false,
      page_title: "Passes",
      sats: Satellites.list_satellites()
    )
  end

  defp assign_sats(socket) do
    assign(socket, sats: Satellites.list_satellites())
  end

  defp assign_pass_filter_changeset(socket) do
    pass_filter = Passes.get_pass_filter(socket.assigns.context.user)
    assign(socket, pass_filter: pass_filter, pass_filter_changeset: Passes.change_pass_filter(pass_filter))
  end

  defp maybe_append_upcoming_passes(socket) do
    if connected?(socket) do
      append_upcoming_passes(socket)
    else
      socket
    end
  end

  defp append_upcoming_passes(%{assigns: %{context: %{location: nil}}} = socket) do
    socket
    |> assign(
      needs_location?: true,
      loading?: false
    )
    |> assign_results_description()
  end

  defp append_upcoming_passes(%{assigns: %{date: nil}} = socket) do
    parent = self()
    starting = socket.assigns[:passes_calculated_until] || DateTime.utc_now()
    ending = Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours)

    {:ok, task_pid} =
      Task.start_link(fn ->
        send(
          parent,
          {:more_upcoming_passes_loaded,
           Passes.list_all_passes(socket.assigns.context, socket.assigns.sats,
             starting: starting,
             ending: ending,
             filter: socket.assigns.pass_filter
           )}
        )
      end)

    socket
    |> assign(
      passes_calculated_until: Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours),
      loading?: true,
      failed?: false,
      task_pid: task_pid
    )
    |> assign_results_description()
  end

  defp append_upcoming_passes(%{assigns: %{date: date, context: context}} = socket) do
    parent = self()
    starting = date |> Timex.to_datetime(context.timezone) |> Timex.beginning_of_day()
    ending = date |> Timex.to_datetime(context.timezone) |> Timex.end_of_day()

    {:ok, task_pid} =
      Task.start_link(fn ->
        send(
          parent,
          {:daily_passes_loaded,
           Passes.list_all_passes(context, socket.assigns.sats,
             starting: starting,
             ending: ending,
             filter: socket.assigns.pass_filter
           )}
        )
      end)

    socket
    |> assign(loading?: true, failed?: false, task_pid: task_pid)
    |> assign_results_description()
  end

  defp purge_passed_passes(socket) do
    next_passes = Enum.reject(socket.assigns.passes, &(Pass.progression(&1, socket.assigns.now) == :passed))

    assign(socket, passes: next_passes)
  end

  defp increment_hours(socket, more_hours) do
    next_hours = socket.assigns.hours + more_hours

    socket
    |> assign(
      hours: next_hours,
      can_load_more?: next_hours < 24
    )
    |> append_upcoming_passes()
  end

  def handle_info({:more_upcoming_passes_loaded, passes}, socket) do
    truncated_passes =
      Enum.filter(passes, fn pass ->
        pass.info.aos.datetime
        |> Util.erl_to_utc_datetime()
        |> DateTime.compare(socket.assigns.passes_calculated_until) ==
          :lt
      end)

    next_passes = merge_new_passes(socket.assigns.passes, truncated_passes)

    {:noreply, socket |> assign(passes: next_passes, loading?: false) |> assign_results_description()}
  end

  def handle_info({:daily_passes_loaded, passes}, socket) do
    {:noreply, socket |> assign(passes: passes, loading?: false) |> assign_results_description()}
  end

  def handle_info(:reload_passes, socket) do
    Process.send_after(self(), :reload_passes, @reload_passes_interval)

    socket =
      socket
      |> append_upcoming_passes()
      |> purge_passed_passes()

    {:noreply, assign(socket, now: DateTime.utc_now())}
  end

  def handle_info({:EXIT, _, :normal}, socket), do: {:noreply, socket}

  def handle_info({:EXIT, task_pid, _reason}, %{assigns: %{task_pid: task_pid}} = socket) do
    {:noreply, socket |> assign(loading?: false, failed?: true, task_pid: false) |> assign_results_description()}
  end

  def handle_event("load-more", _, socket) do
    {:noreply, increment_hours(socket, 6)}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "upcoming"}, socket) do
    {:noreply, push_patch(socket, to: ~p"/passes")}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "browse"}, socket) do
    {:noreply, push_patch(socket, to: browse_path(socket.assigns.context.timezone))}
  end

  def handle_event("date-changed", %{"date" => date}, socket) do
    case Date.from_iso8601(date) do
      {:ok, _date} ->
        {:noreply, push_patch(socket, to: ~p"/passes?date=#{date}")}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("filter-changed", %{"pass_filter" => params}, socket) do
    case Passes.update_pass_filter(socket.assigns.pass_filter, params) do
      {:ok, pass_filter} ->
        {:noreply,
         socket
         |> assign(
           pass_filter_changeset: Passes.change_pass_filter(pass_filter),
           pass_filter: pass_filter,
           passes_calculated_until: nil,
           passes: []
         )
         |> maybe_append_upcoming_passes()}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp merge_new_passes(old_passes, new_passes) do
    old_passes_map = for pass <- old_passes, into: %{}, do: {pass.hash, pass}
    new_passes_map = for pass <- new_passes, into: %{}, do: {pass.hash, pass}

    old_passes_map
    |> Map.merge(new_passes_map)
    |> Map.values()
    |> Enum.sort_by(& &1.info.aos.datetime)
  end

  defp duration_options do
    [upcoming: "Upcoming", browse: "Browse"]
  end

  defp browse_path(timezone) do
    default_date = timezone |> Timex.today() |> Date.to_iso8601()
    ~p"/passes?date=#{default_date}"
  end

  def assign_results_description(%{assigns: %{needs_location?: true}} = socket) do
    assign(socket, results_description: nil)
  end

  def assign_results_description(%{assigns: %{loading?: true}} = socket) do
    assign(socket, results_description: "Calculating…")
  end

  def assign_results_description(%{assigns: %{duration: :upcoming}} = socket) do
    grid =
      Hamsat.Grid.encode!(
        socket.assigns.context.location.lat,
        socket.assigns.context.location.lon,
        6
      )

    assign(
      socket,
      results_description:
        "Found #{length(socket.assigns.passes)} passes visible from #{grid} within the next #{socket.assigns.hours} hours."
    )
  end

  def assign_results_description(%{assigns: %{duration: :browse}} = socket) do
    grid =
      Hamsat.Grid.encode!(
        socket.assigns.context.location.lat,
        socket.assigns.context.location.lon,
        6
      )

    assign(
      socket,
      results_description:
        "Found #{length(socket.assigns.passes)} passes visible from #{grid} on #{Date.to_iso8601(socket.assigns.date)}."
    )
  end
end
