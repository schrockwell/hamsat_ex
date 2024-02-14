defmodule HamsatWeb.PassesLive.Components.PassTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias HamsatWeb.SatComponents

  prop :context
  prop :now
  prop :pass

  state :next_event_in
  state :row_class
  state :show_create_button?
  state :show_edit_button?

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
      put_state(socket, next_event_in: pass_next_event_in(socket.assigns.now, socket.assigns.pass))
    else
      socket
    end
  end

  defp assign_row_class(socket) do
    if changed?(socket, :now) do
      put_state(socket, row_class: pass_table_row_class(socket.assigns.pass, socket.assigns.now))
    else
      socket
    end
  end

  defp assign_show_create_button(socket) do
    if changed?(socket, :now) do
      put_state(socket,
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
      put_state(socket,
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
