defmodule HamsatWeb.Dashboard.ShowLive do
  use HamsatWeb, :live_view

  alias HamsatWeb.Dashboard.Components.AlertsList
  alias HamsatWeb.Dashboard.Components.PassesList

  def mount(_params, _session, socket) do
    Process.send_after(self(), :set_now, 1_000)

    {:ok,
     socket
     |> assign(:page_title, "Home")
     |> assign_now()}
  end

  def handle_info(:set_now, socket) do
    Process.send_after(self(), :set_now, 1_000)
    {:noreply, assign_now(socket)}
  end

  defp assign_now(socket) do
    assign(socket, :now, DateTime.utc_now())
  end
end
