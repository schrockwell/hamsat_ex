defmodule Hamsat.Satellites.PeriodicSync do
  use GenServer

  alias Hamsat.Satellites

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def updated_at do
    GenServer.call(__MODULE__, :updated_at)
  end

  def init(_) do
    initial_state = %{updated_at: nil}

    {:ok, do_sync(initial_state)}
  end

  def handle_info(:sync, state) do
    {:noreply, do_sync(state)}
  end

  defp do_sync(state) do
    state =
      case Satellites.sync_now() do
        {:ok, updated_at} -> %{state | updated_at: updated_at}
        _ -> state
      end

    # this purge isn't really necessary here, but it's a good time to do it
    Hamsat.Alerts.PassCache.purge_all()

    Hamsat.PubSub.broadcast_satellites_updated()
    Process.send_after(self(), :sync, :timer.hours(24))

    state
  end

  def handle_call(:updated_at, _from, %{updated_at: %DateTime{} = updated_at} = state) do
    {:reply, updated_at, state}
  end

  def handle_call(:updated_at, _from, state) do
    {:reply, nil, state}
  end
end
