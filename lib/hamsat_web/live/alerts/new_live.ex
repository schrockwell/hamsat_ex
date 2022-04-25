defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts

  def mount(%{"pass" => pass_hash}, _, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)

    IO.inspect(pass, label: "pass")

    socket =
      socket
      |> assign(:pass, pass)

    {:ok, socket}
  end
end
