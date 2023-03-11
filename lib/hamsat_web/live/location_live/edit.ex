defmodule HamsatWeb.LocationLive.Edit do
  use HamsatWeb, :live_view

  alias HamsatWeb.LocationSetter

  state :page_title, default: "Set Location"
  state :redirect_path

  def mount(params, _session, socket) do
    socket = put_state(socket, redirect_path: params["redirect"])

    {:ok, socket}
  end
end
