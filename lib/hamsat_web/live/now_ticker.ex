defmodule HamsatWeb.Live.NowTicker do
  @moduledoc """
  Assigns `:now` and keeps it ticking.

  By default `:now` is reassigned every second, which re-renders everything in
  the template that references it. That is right for pages that really change
  every second (satellite positions on a pass page), and wasteful for list
  pages, where the clock only matters at the moment an activation or pass
  starts or ends. Those pages pass a `:fingerprint` function instead:

      on_mount {HamsatWeb.Live.NowTicker, fingerprint: {__MODULE__, :now_fingerprint}}

      def now_fingerprint(assigns, now) do
        for alert <- assigns.alerts, do: {alert.id, Alert.progression(alert, now)}
      end

  The fingerprint is computed with the fresh clock on every tick, and `:now`
  is only reassigned when it differs from the last one, so an idle page renders
  nothing at all. In exchange, `:now` can lag the clock on those pages: use it
  only for state the fingerprint covers, and let time displays tick in the
  browser (see `HamsatWeb.CountdownComponents`).
  """
  import Phoenix.Component
  import Phoenix.LiveView

  @message {__MODULE__, :tick}

  def on_mount(:default, params, session, socket) do
    on_mount([], params, session, socket)
  end

  def on_mount(tick_interval, params, session, socket) when is_integer(tick_interval) do
    on_mount([interval: tick_interval], params, session, socket)
  end

  def on_mount(opts, _params, _session, socket) when is_list(opts) do
    tick_interval = Keyword.get(opts, :interval, 1_000)
    fingerprint = Keyword.get(opts, :fingerprint)

    socket = assign(socket, now: DateTime.utc_now(), now_fingerprint: nil)

    if connected?(socket) do
      Process.send_after(self(), @message, tick_interval)
    end

    {:cont,
     attach_hook(socket, __MODULE__, :handle_info, fn
       @message, socket ->
         Process.send_after(self(), @message, tick_interval)
         {:halt, tick(socket, fingerprint)}

       _msg, socket ->
         {:cont, socket}
     end)}
  end

  defp tick(socket, nil), do: assign(socket, :now, DateTime.utc_now())

  defp tick(socket, {module, function}) do
    now = DateTime.utc_now()
    fingerprint = apply(module, function, [socket.assigns, now])

    if fingerprint == socket.assigns.now_fingerprint do
      socket
    else
      assign(socket, now: now, now_fingerprint: fingerprint)
    end
  end
end
