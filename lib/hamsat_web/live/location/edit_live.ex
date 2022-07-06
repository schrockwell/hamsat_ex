defmodule HamsatWeb.Location.EditLive do
  use HamsatWeb, :live_view

  alias HamsatWeb.LocationSetter

  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Set Location")
      |> assign(:redirect_path, params["redirect"])

    {:ok, socket}
  end
end
