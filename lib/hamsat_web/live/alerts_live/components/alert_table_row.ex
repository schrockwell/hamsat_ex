defmodule HamsatWeb.Alerts.Components.AlertTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Schemas.Alert
  alias HamsatWeb.LiveComponents.AlertSaver
  alias HamsatWeb.SatComponents

  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :alerts, :list, required: true

  def table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table w-full">
        <thead>
          <tr>
            <th></th>
            <th class="pl-6">Time</th>
            <th>Callsign</th>
            <th>Sat</th>
            <th>Grid</th>
            <th>Freq</th>
            <th>Mode</th>
            <th>Comment</th>
            <th>Match</th>
            <th>Max El</th>
            <th>Visible</th>
            <th>Visible</th>
            <th></th>
          </tr>
        </thead>

        <%= for alert <- @alerts do %>
          <.row id={alert.id} alert={alert} now={@now} context={@context} />
        <% end %>
      </table>
    </div>
    """
  end

  attr :alert, Alert, required: true
  attr :context, Hamsat.Context, required: true
  attr :id, :string, required: true
  attr :now, DateTime, required: true

  def row(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={@id} alert={@alert} context={@context} now={@now} />
    """
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_row_class()
     |> assign_next_workable_in()}
  end

  defp alert_table_row_class(alert, now) do
    case Alert.progression(alert, now) do
      :upcoming ->
        ""

      :workable ->
        "bg-green-100 text-emerald-700 font-semibold"

      p when p in [:in_progress, :before_workable, :after_workable] ->
        "bg-yellow-100 text-yellow-800 font-semibold"

      :passed ->
        "text-gray-400"
    end
  end

  defp assign_row_class(socket) do
    assign(socket, row_class: alert_table_row_class(socket.assigns.alert, socket.assigns.now))
  end

  defp assign_next_workable_in(socket) do
    assign(socket, next_workable_in: alert_next_workable_in(socket.assigns.now, socket.assigns.alert))
  end
end
