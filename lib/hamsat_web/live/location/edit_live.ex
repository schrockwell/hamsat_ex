defmodule HamsatWeb.Location.EditLive do
  use HamsatWeb, :live_view

  alias HamsatWeb.LocationPicker

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Set Location")
      |> assign(:coord, socket.assigns.context.location)
      |> assign(:redirect_path, params["redirect"])

    {:ok, socket}
  end

  def handle_info({LocationPicker, :coord_selected, coord}, socket) do
    socket = assign(socket, :coord, coord)
    {:noreply, socket}
  end
end
