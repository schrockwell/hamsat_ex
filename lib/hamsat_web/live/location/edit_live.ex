defmodule HamsatWeb.Location.EditLive do
  use HamsatWeb, :love_view

  alias HamsatWeb.LocationSetter

  state :page_title, default: "Set Location"

  computed :redirect_path

  def mount(params, _session, socket) do
    socket =
      socket
      |> put_computed(:redirect_path, params["redirect"])

    {:ok, socket}
  end
end
