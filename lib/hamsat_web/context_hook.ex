defmodule HamsatWeb.ContextHook do
  def on_mount(:default, _params, session, socket) do
    {:cont,
     Phoenix.LiveView.assign_new(socket, :context, fn -> Hamsat.Context.from_session(session) end)}
  end
end
