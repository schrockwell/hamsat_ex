defmodule HamsatWeb.PassesLive.Components.PassTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias HamsatWeb.SatComponents

  attr :context, Hamsat.Context, required: true
  attr :now, DateTime, required: true
  attr :passes, :list, required: true

  def table(assigns) do
    ~H"""
    <div class="mt-2 overflow-x-auto">
      <table class="table w-full">
        <thead>
          <tr>
            <th class="whitespace-nowrap px-1" title="Time of acquisition of signal">AOS</th>
            <th class="whitespace-nowrap px-1" title="Time until acquisition or loss of signal">Next Event</th>
            <th class="whitespace-nowrap px-1" title="Satellite name and modulation">Sat</th>
            <th class="whitespace-nowrap px-1" title="Duration of visible pass">Length</th>
            <th class="whitespace-nowrap px-1" title="Max elevation during pass">Max El</th>
            <th class="whitespace-nowrap px-1" colspan="3" title="Azimuth of satellite during pass">Az</th>
            <th class="whitespace-nowrap px-1" title="Activation alerts">Alerts</th>
            <th class="whitespace-nowrap px-1"></th>
          </tr>
        </thead>
        <tbody>
          <%= for pass <- @passes do %>
            <.row id={Pass.encode_hash(pass)} context={@context} pass={pass} now={@now} />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :context, Hamsat.Context, required: true
  attr :id, :string, required: true
  attr :now, DateTime, required: true
  attr :pass, Pass, required: true

  def row(assigns) do
    ~H"""
    <.live_component module={__MODULE__} id={@id} context={@context} now={@now} pass={@pass} />
    """
  end

  defp pass_table_row_class(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming -> ""
      :in_progress -> "bg-emerald-100 text-emerald-700 font-semibold"
      :passed -> "text-gray-400"
    end
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_next_event_in()
     |> assign_row_class()
     |> assign_show_create_button()
     |> assign_show_edit_button()}
  end

  defp assign_next_event_in(socket) do
    if changed?(socket, :now) do
      assign(socket, next_event_in: pass_next_event_in(socket.assigns.now, socket.assigns.pass))
    else
      socket
    end
  end

  defp assign_row_class(socket) do
    if changed?(socket, :now) do
      assign(socket, row_class: pass_table_row_class(socket.assigns.pass, socket.assigns.now))
    else
      socket
    end
  end

  defp assign_show_create_button(socket) do
    if changed?(socket, :now) do
      assign(socket,
        show_create_button?:
          Alerts.show_create_alert_button?(
            socket.assigns.context,
            socket.assigns.pass,
            socket.assigns.now
          )
      )
    else
      socket
    end
  end

  defp assign_show_edit_button(socket) do
    if changed?(socket, :now) do
      assign(socket,
        show_edit_button?:
          Alerts.show_edit_alert_button?(
            socket.assigns.context,
            socket.assigns.pass,
            socket.assigns.now
          )
      )
    else
      socket
    end
  end
end
