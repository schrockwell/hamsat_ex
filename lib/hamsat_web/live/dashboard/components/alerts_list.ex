defmodule HamsatWeb.Dashboard.Components.AlertsList do
  use HamsatWeb, :live_component

  alias HamsatWeb.Dashboard.Components.AlertItem

  def mount(socket) do
    socket =
      socket
      |> assign(:mine?, false)

    {:ok, socket}
  end
end
