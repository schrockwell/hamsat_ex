defmodule HamsatWeb.Passes.IndexLive do
  use HamsatWeb, :live_view

  import HamsatWeb.PassComponents
  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Satellites
  alias Hamsat.Util

  @set_now_interval :timer.seconds(1)
  @reload_passes_interval :timer.minutes(15)

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:loading?, true)
      |> assign_sats()
      |> assign_results_description()

    Process.send_after(self(), :set_now, @set_now_interval)
    Process.send_after(self(), :reload_passes, @reload_passes_interval)

    {:ok, socket}
  end

  def handle_params(%{"date" => date}, _uri, socket) do
    socket =
      case Date.from_iso8601(date) do
        {:ok, date} -> assign(socket, :date, date)
        {:error, _} -> assign(socket, :date, Date.utc_today())
      end

    {:noreply,
     socket
     |> assign(:duration, :browse)
     |> assign(:can_load_more?, false)
     |> assign(:now, DateTime.utc_now())
     |> assign(:passes, [])
     |> maybe_append_upcoming_passes()}
  end

  def handle_params(_, _uri, socket) do
    {:noreply,
     socket
     |> assign(:duration, :upcoming)
     |> assign(:hours, 6)
     |> assign(:date, nil)
     |> assign(:can_load_more?, true)
     |> assign(:now, DateTime.utc_now())
     |> assign(:date, nil)
     |> assign(:passes, [])
     |> assign(:passes_calculated_until, nil)
     |> maybe_append_upcoming_passes()}
  end

  defp assign_sats(socket) do
    assign(socket, :sats, Satellites.list_satellites())
  end

  defp maybe_append_upcoming_passes(socket) do
    if connected?(socket) do
      append_upcoming_passes(socket)
    else
      socket
    end
  end

  defp append_upcoming_passes(%{assigns: %{date: nil}} = socket) do
    parent = self()
    starting = socket.assigns[:passes_calculated_until] || DateTime.utc_now()
    ending = Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours)

    Task.start(fn ->
      send(
        parent,
        {:more_upcoming_passes_loaded,
         Alerts.list_all_passes(socket.assigns.context, socket.assigns.sats,
           starting: starting,
           ending: ending
         )}
      )
    end)

    socket
    |> assign(
      :passes_calculated_until,
      Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours)
    )
    |> assign(:loading?, true)
    |> assign_results_description()
  end

  defp append_upcoming_passes(%{assigns: %{date: date}} = socket) do
    parent = self()
    starting = date |> Timex.to_datetime() |> Timex.beginning_of_day()
    ending = date |> Timex.to_datetime() |> Timex.end_of_day()

    Task.start(fn ->
      send(
        parent,
        {:daily_passes_loaded,
         Alerts.list_all_passes(socket.assigns.context, socket.assigns.sats,
           starting: starting,
           ending: ending
         )}
      )
    end)

    socket
    |> assign(:loading?, true)
    |> assign_results_description()
  end

  defp purge_passed_passes(socket) do
    next_passes =
      Enum.reject(socket.assigns.passes, &(Pass.progression(&1, socket.assigns.now) == :passed))

    socket
    |> assign(:passes, next_passes)
    |> assign_results_description()
  end

  defp increment_hours(socket, more_hours) do
    next_hours = socket.assigns.hours + more_hours

    socket
    |> assign(:hours, next_hours)
    |> assign(:can_load_more?, next_hours < 24)
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

    {:noreply,
     socket
     |> assign(:passes, next_passes)
     |> assign(:loading?, false)
     |> assign_results_description()}
  end

  def handle_info({:daily_passes_loaded, passes}, socket) do
    {:noreply,
     socket
     |> assign(:passes, passes)
     |> assign(:loading?, false)
     |> assign_results_description()}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, @set_now_interval)
    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  def handle_info(:reload_passes, socket) do
    Process.send_after(self(), :reload_passes, @reload_passes_interval)

    socket =
      socket
      |> append_upcoming_passes()
      |> purge_passed_passes()

    {:noreply, assign(socket, :now, DateTime.utc_now())}
  end

  def handle_event("load-more", _, socket) do
    {:noreply, increment_hours(socket, 6)}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "upcoming"}, socket) do
    {:noreply, push_patch(socket, to: Routes.passes_path(socket, :index))}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "browse"}, socket) do
    {:noreply, push_patch(socket, to: browse_url(socket))}
  end

  def handle_event("date-changed", %{"date" => date}, socket) do
    case Date.from_iso8601(date) do
      {:ok, _date} ->
        {:noreply, push_patch(socket, to: Routes.passes_path(socket, :index, date: date))}

      _ ->
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

  defp browse_url(socket) do
    default_date = Date.utc_today() |> Timex.shift(days: 1) |> Date.to_iso8601()
    Routes.passes_path(socket, :index, date: default_date)
  end

  defp assign_results_description(%{assigns: %{loading?: true}} = socket) do
    assign(socket, :results_description, "Calculating…")
  end

  defp assign_results_description(%{assigns: %{duration: :upcoming}} = socket) do
    grid =
      Hamsat.Grid.encode!(
        socket.assigns.context.location.lat,
        socket.assigns.context.location.lon,
        6
      )

    assign(
      socket,
      :results_description,
      "Found #{length(socket.assigns.passes)} passes visible from #{grid} within the next #{socket.assigns.hours} hours."
    )
  end

  defp assign_results_description(%{assigns: %{duration: :browse}} = socket) do
    grid =
      Hamsat.Grid.encode!(
        socket.assigns.context.location.lat,
        socket.assigns.context.location.lon,
        6
      )

    assign(
      socket,
      :results_description,
      "Found #{length(socket.assigns.passes)} passes visible from #{grid} on #{Date.to_iso8601(socket.assigns.date)}."
    )
  end
end
