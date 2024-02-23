defmodule HamsatWeb.Live.NowTicker do
  import Phoenix.Component
  import Phoenix.LiveView

  @message {__MODULE__, :tick}

  def on_mount(:default, params, session, socket) do
    on_mount(1_000, params, session, socket)
  end

  def on_mount(tick_interval, _params, _session, socket) when is_integer(tick_interval) do
    socket = assign(socket, :now, DateTime.utc_now())

    if connected?(socket) do
      Process.send_after(self(), @message, tick_interval)
    end

    {:cont,
     attach_hook(socket, __MODULE__, :handle_info, fn
       @message, socket ->
         Process.send_after(self(), @message, tick_interval)
         {:halt, assign(socket, :now, DateTime.utc_now())}

       _msg, socket ->
         {:cont, socket}
     end)}
  end
end
