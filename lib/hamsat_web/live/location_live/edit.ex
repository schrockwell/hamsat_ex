defmodule HamsatWeb.LocationLive.Edit do
  use HamsatWeb, :live_view

  alias HamsatWeb.LocationSetter

  def mount(params, _session, socket) do
    socket = assign(socket, page_title: "Set Location", redirect_path: params["redirect"])

    {:ok, socket}
  end
end
