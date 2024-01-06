defmodule HamsatWeb.PassesLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts.Pass
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Util
  alias HamsatWeb.PassesLive.Components.PassTableRow
  alias HamsatWeb.LocationSetter

  @set_now_interval :timer.seconds(1)
  @reload_passes_interval :timer.minutes(15)

  state :can_load_more?
  state :date
  state :duration
  state :hours
  state :loading?, default: true
  state :needs_location?, default: false
  state :now, default: DateTime.utc_now()
  state :page_title, default: "Passes"
  state :pass_filter
  state :pass_filter_changeset
  state :passes
  state :passes_calculated_until
  state :results_description
  state :sats, default: Satellites.list_satellites()

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_sats()
      |> assign_pass_filter_changeset()

    if connected?(socket) do
      Process.send_after(self(), :set_now, @set_now_interval)
      Process.send_after(self(), :reload_passes, @reload_passes_interval)
    end

    {:ok, socket}
  end

  def handle_params(%{"date" => date}, _uri, socket) do
    socket =
      case Date.from_iso8601(date) do
        {:ok, date} -> put_state(socket, date: date)
        {:error, _} -> put_state(socket, date: Timex.today(socket.assigns.context.timezone))
      end

    {:noreply,
     socket
     |> put_state(
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
     |> put_state(
       duration: :upcoming,
       hours: 6,
       date: nil,
       can_load_more?: true,
       passes: [],
       passes_calculated_until: nil
     )
     |> maybe_append_upcoming_passes()}
  end

  defp assign_sats(socket) do
    put_state(socket, sats: Satellites.list_satellites())
  end

  defp assign_pass_filter_changeset(socket) do
    pass_filter = Passes.get_pass_filter(socket.assigns.context.user)
    put_state(socket, pass_filter: pass_filter, pass_filter_changeset: Passes.change_pass_filter(pass_filter))
  end

  defp maybe_append_upcoming_passes(socket) do
    if connected?(socket) do
      append_upcoming_passes(socket)
    else
      socket
    end
  end

  defp append_upcoming_passes(%{assigns: %{context: %{location: nil}}} = socket) do
    put_state(socket,
      needs_location?: true,
      loading?: false
    )
  end

  defp append_upcoming_passes(%{assigns: %{date: nil}} = socket) do
    parent = self()
    starting = socket.assigns[:passes_calculated_until] || DateTime.utc_now()
    ending = Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours)

    Task.start(fn ->
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
    |> put_state(
      passes_calculated_until: Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours),
      loading?: true
    )
  end

  defp append_upcoming_passes(%{assigns: %{date: date, context: context}} = socket) do
    parent = self()
    starting = date |> Timex.to_datetime(context.timezone) |> Timex.beginning_of_day()
    ending = date |> Timex.to_datetime(context.timezone) |> Timex.end_of_day()

    Task.start(fn ->
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

    put_state(socket, loading?: true)
  end

  defp purge_passed_passes(socket) do
    next_passes = Enum.reject(socket.assigns.passes, &(Pass.progression(&1, socket.assigns.now) == :passed))

    put_state(socket, passes: next_passes)
  end

  defp increment_hours(socket, more_hours) do
    next_hours = socket.assigns.hours + more_hours

    socket
    |> put_state(
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

    {:noreply, put_state(socket, passes: next_passes, loading?: false)}
  end

  def handle_info({:daily_passes_loaded, passes}, socket) do
    {:noreply, put_state(socket, passes: passes, loading?: false)}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, @set_now_interval)
    {:noreply, put_state(socket, now: DateTime.utc_now())}
  end

  def handle_info(:reload_passes, socket) do
    Process.send_after(self(), :reload_passes, @reload_passes_interval)

    socket =
      socket
      |> append_upcoming_passes()
      |> purge_passed_passes()

    {:noreply, put_state(socket, now: DateTime.utc_now())}
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
         |> put_state(
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

  @react to: [:needs_location?, :loading?, :duration]
  def assign_results_description(%{assigns: %{needs_location?: true}} = socket) do
    put_state(socket, results_description: nil)
  end

  def assign_results_description(%{assigns: %{loading?: true}} = socket) do
    put_state(socket, results_description: "Calculating…")
  end

  def assign_results_description(%{assigns: %{duration: :upcoming}} = socket) do
    grid =
      Hamsat.Grid.encode!(
        socket.assigns.context.location.lat,
        socket.assigns.context.location.lon,
        6
      )

    put_state(
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

    put_state(
      socket,
      results_description:
        "Found #{length(socket.assigns.passes)} passes visible from #{grid} on #{Date.to_iso8601(socket.assigns.date)}."
    )
  end
end
