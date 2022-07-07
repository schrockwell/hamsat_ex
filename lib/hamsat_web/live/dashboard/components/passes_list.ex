defmodule HamsatWeb.Dashboard.Components.PassesList do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Satellites
  alias HamsatWeb.Dashboard.Components.PassItem
  alias HamsatWeb.LocationSetter

  def mount(socket) do
    socket =
      socket
      |> assign(:loading?, true)
      |> assign(:passes, [])
      |> assign_sats()
      |> assign_pass_opts()

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> fetch_passes_async()

    {:ok, socket}
  end

  defp assign_sats(socket) do
    assign(socket, :sats, Satellites.list_satellites())
  end

  defp assign_pass_opts(socket) do
    assign(socket, :pass_opts,
      starting: DateTime.utc_now(),
      ending: Timex.shift(DateTime.utc_now(), hours: 6)
    )
  end

  defp fetch_passes_async(socket) do
    if connected?(socket) and changed?(socket, :pass_opts) and socket.assigns.context.location do
      pid = self()

      Task.async(fn ->
        passes =
          Alerts.list_all_passes(
            socket.assigns.context,
            socket.assigns.sats,
            socket.assigns.pass_opts
          )

        send_update(pid, __MODULE__, id: socket.assigns.id, passes: passes, loading?: false)
      end)
    end

    socket
  end
end
