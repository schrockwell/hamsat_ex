defmodule HamsatWeb.AlertsLive.Index do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias HamsatWeb.Alerts.Components.AlertTableRow

  on_mount {HamsatWeb.Live.NowTicker, fingerprint: {__MODULE__, :now_fingerprint}}

  # Rows change style as activations progress (see NowTicker)
  def now_fingerprint(assigns, now) do
    for alert <- assigns.alerts, do: {alert.id, Hamsat.Schemas.Alert.progression(alert, now)}
  end

  def mount(params, _session, socket) do
    print? = params["print"] == "1"

    if connected?(socket) and not print? do
      Phoenix.PubSub.subscribe(Hamsat.PubSub, "alerts")
    end

    socket = assign(socket, page_title: "Activations", print?: print?, printed_at: DateTime.utc_now())

    # The printer-friendly view is a static snapshot of the same search
    # results, swapping the app chrome for a bare layout
    if print? do
      {:ok, socket, layout: {HamsatWeb.LayoutView, :print}}
    else
      {:ok, socket}
    end
  end

  def handle_params(params, _uri, socket) do
    filter = [date: parse_date_filter(params)]
    alerts = Alerts.list_alerts(socket.assigns.context, filter)

    duration = if filter[:date] == :upcoming, do: :upcoming, else: :browse

    {:noreply,
     assign(socket,
       filter: filter,
       alerts: alerts,
       duration: duration
     )}
  end

  defp parse_date_filter(params) do
    with %{"date" => date_string} <- params,
         {:ok, date} <- Date.from_iso8601(date_string) do
      date
    else
      _ -> :upcoming
    end
  end

  def handle_event("select", %{"id" => "interval", "selected" => "upcoming"}, socket) do
    {:noreply, push_patch(socket, to: ~p"/alerts")}
  end

  def handle_event("select", %{"id" => "interval", "selected" => "browse"}, socket) do
    {:noreply, push_patch(socket, to: browse_path(socket.assigns.context.timezone))}
  end

  def handle_event("date-changed", params, socket) do
    params = Map.take(params, ["date"])
    socket = push_patch(socket, to: ~p"/alerts?#{params}")

    {:noreply, socket}
  end

  def handle_info({event, _info} = message, socket)
      when event in [:alert_saved, :alert_unsaved] do
    {:noreply,
     assign(
       socket,
       alerts: Alerts.patch_alerts(socket.assigns.alerts, socket.assigns.context, message)
     )}
  end

  defp duration_options do
    [upcoming: "Upcoming", browse: "Browse"]
  end

  defp browse_path(timezone) do
    params = %{date: timezone |> Timex.today() |> Date.to_iso8601()}
    ~p"/alerts?#{params}"
  end

  # Layout is fixed at mount, so switching to and from the print view must be
  # a full page load (plain hrefs, not patches)
  defp print_path(filter) do
    case filter[:date] do
      %Date{} = date -> ~p"/alerts?#{%{date: Date.to_iso8601(date), print: 1}}"
      _ -> ~p"/alerts?#{%{print: 1}}"
    end
  end

  defp print_title(%{duration: :upcoming}), do: "Upcoming Satellite Activations"
  defp print_title(%{filter: filter}), do: "Satellite Activations on #{filter[:date]}"

  # Comments are freeform text, so tidy them up for the printed page
  defp print_comment(nil), do: nil

  defp print_comment(comment) do
    case String.trim(comment) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
