defmodule HamsatWeb.LocationLive.Modal do
  use HamsatWeb, :child_live_view

  alias HamsatWeb.LocationSetter

  def mount(_params, session, socket) do
    {:ok, assign(socket, redirect: session["redirect"])}
  end

  def render(assigns) do
    ~H"""
    <LocationSetter.component
      id="location-modal-setter"
      context={@context}
      redirect={@redirect}
      show_log_in_link?={@context.user == :guest}
    />
    """
  end
end
