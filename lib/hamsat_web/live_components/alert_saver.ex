defmodule HamsatWeb.LiveComponents.AlertSaver do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts

  prop :alert
  prop :button_class, default: nil
  prop :class, default: nil
  prop :context
  prop :readonly?, default: false

  def handle_event("toggle-save", _, socket) do
    if socket.assigns.alert.saved? do
      Alerts.unsave_alert(socket.assigns.context, socket.assigns.alert)
    else
      Alerts.save_alert(socket.assigns.context, socket.assigns.alert)
    end

    {:noreply, socket}
  end

  defp icon_type(alert) do
    if alert.saved?, do: "solid", else: "outline"
  end

  def render(assigns) do
    if assigns.readonly? or assigns.context.user == :guest do
      ~H"""
      <div class={@class}>
        <div class="flex justify-between items-center space-x-1 h-full">
          <div><Heroicons.LiveView.icon name="thumb-up" type="outline" class="h-4 w-4" /></div>
          <div><%= @alert.saved_count %></div>
        </div>
      </div>
      """
    else
      ~H"""
      <button phx-click="toggle-save" phx-target={@myself} class={[@class, @button_class]}>
        <div class="flex justify-between items-center space-x-1">
          <div><Heroicons.LiveView.icon name="thumb-up" type={icon_type(@alert)} class="h-4 w-4" /></div>
          <div><%= @alert.saved_count %></div>
        </div>
      </button>
      """
    end
  end
end
