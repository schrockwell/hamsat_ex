defmodule HamsatWeb.NavPlug do
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    assign(conn, :active_nav_item, HamsatWeb.ViewHelpers.active_nav_item(conn.request_path))
  end
end
