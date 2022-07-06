defmodule HamsatWeb.ContextPlug do
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    assign(conn, :context, Hamsat.Context.from_session(get_session(conn)))
  end
end
