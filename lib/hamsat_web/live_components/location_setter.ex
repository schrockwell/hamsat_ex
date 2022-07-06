defmodule HamsatWeb.LocationSetter do
  use HamsatWeb, :live_component

  alias HamsatWeb.LocationPicker

  def mount(socket) do
    {:ok, assign(socket, :show_log_in_link?, false)}
  end

  def update(%{__location_picker_coord_selected__: coord}, socket) do
    {:ok, assign(socket, :coord, coord)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> extract_context_coord()}
  end

  defp extract_context_coord(socket) do
    if changed?(socket, :context) do
      assign(socket, :coord, socket.assigns.context.location)
    end
  end
end
