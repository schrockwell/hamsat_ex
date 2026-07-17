defmodule HamsatWeb.ContextPlug do
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    conn
    |> assign(:context, Hamsat.Context.from_session(get_session(conn)))
    |> assign(:keps_updated_at, Hamsat.Satellites.PeriodicSync.updated_at())
  end
end
