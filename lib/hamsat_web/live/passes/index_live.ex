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
      |> assign(:hours, 6)
      |> assign(:can_load_more?, true)
      |> assign(:passes, [])
      |> assign(:loading?, true)
      |> assign(:now, DateTime.utc_now())
      |> assign_sats()

    Process.send_after(self(), :set_now, @set_now_interval)
    Process.send_after(self(), :reload_passes, @reload_passes_interval)

    socket =
      if connected?(socket) do
        append_upcoming_passes(socket)
      else
        socket
      end

    {:ok, socket}
  end

  defp assign_sats(socket) do
    assign(socket, :sats, Satellites.list_satellites())
  end

  defp append_upcoming_passes(socket) do
    parent = self()
    starting = socket.assigns[:passes_calculated_until] || DateTime.utc_now()
    ending = Timex.shift(DateTime.utc_now(), hours: socket.assigns.hours)

    Task.start(fn ->
      send(
        parent,
        {:passes_loaded,
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
  end

  defp purge_passed_passes(socket) do
    next_passes = Enum.reject(socket.assigns.passes, &(Pass.progression(&1) == :passed))
    assign(socket, :passes, next_passes)
  end

  defp increment_hours(socket, more_hours) do
    next_hours = socket.assigns.hours + more_hours

    socket
    |> assign(:hours, next_hours)
    |> assign(:can_load_more?, next_hours < 24)
    |> append_upcoming_passes()
  end

  def handle_info({:passes_loaded, passes}, socket) do
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
     |> assign(:loading?, false)}
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
end
