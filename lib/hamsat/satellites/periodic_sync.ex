defmodule Hamsat.Satellites.PeriodicSync do
  use GenServer

  alias Hamsat.Satellites

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    do_sync()
    {:ok, nil}
  end

  def handle_info(:sync, nil) do
    do_sync()
    {:noreply, nil}
  end

  defp do_sync do
    Satellites.sync_now()
    Process.send_after(self(), :sync, :timer.hours(24))
  end
end
