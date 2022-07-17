defmodule HamsatWeb.LiveComponents.AlertSaver do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts

  def mount(socket) do
    {:ok,
     socket
     |> assign(:class, nil)
     |> assign(:button_class, nil)
     |> assign(:readonly?, false)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_icon_type()}
  end

  def handle_event("toggle-save", _, socket) do
    if socket.assigns.alert.saved? do
      Alerts.unsave_alert(socket.assigns.context, socket.assigns.alert)
    else
      Alerts.save_alert(socket.assigns.context, socket.assigns.alert)
    end

    {:noreply, socket}
  end

  defp assign_icon_type(socket) do
    icon_type = if socket.assigns.alert.saved?, do: "solid", else: "outline"
    assign(socket, :icon_type, icon_type)
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
              <div><Heroicons.LiveView.icon name="thumb-up" type={@icon_type} class="h-4 w-4" /></div>
              <div><%= @alert.saved_count %></div>
          </div>
      </button>
      """
    end
  end
end
