defmodule HamsatWeb.Dashboard.Components.PassesList do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Satellites
  alias HamsatWeb.Dashboard.Components.PassItem

  def mount(socket) do
    socket =
      socket
      |> assign_sats()
      |> assign_pass_opts()

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_passes()

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

  defp assign_passes(socket) do
    if changed?(socket, :pass_opts) do
      passes =
        Alerts.list_all_passes(
          socket.assigns.context,
          socket.assigns.sats,
          socket.assigns.pass_opts
        )

      assign(socket, :passes, passes)
    else
      socket
    end
  end
end
