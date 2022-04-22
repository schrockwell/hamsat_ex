defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :live_component

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:coords, fn -> {0, 0} end)

    {:ok, socket}
  end

  def handle_event("form-changed", params, socket) do
    IO.inspect(params)
    {:noreply, socket}
  end
end
