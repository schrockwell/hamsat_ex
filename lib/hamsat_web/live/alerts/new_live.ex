defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Grid

  def mount(%{"pass" => pass_hash}, _, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)

    IO.inspect(pass, label: "pass")

    socket =
      socket
      |> assign(:pass, pass)
      |> assign(:sat, pass.sat)
      |> assign(:grid, Grid.encode!(pass.observer.latitude_deg, pass.observer.longitude_deg, 6))

    {:ok, socket}
  end

  defp form_row(%{label: label} = assigns) do
    ~H"""
    <fieldset class="flex space-x-8">
      <div class="w-48 text-right font-medium"><%= @label %></div>
      <div><%= render_slot @inner_block %></div>
    </fieldset>
    """
  end
end
