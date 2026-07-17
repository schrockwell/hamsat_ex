defmodule HamsatWeb.ContextHook do
  def on_mount(:default, _params, session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign_new(:context, fn -> Hamsat.Context.from_session(session) end)
     |> Phoenix.Component.assign_new(:keps_updated_at, fn -> Hamsat.Satellites.PeriodicSync.updated_at() end)}
  end
end
