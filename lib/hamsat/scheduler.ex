defmodule Hamsat.Scheduler do
  use GenServer

  require Logger

  @task_intervals %{
    purge_pass_cache: :timer.hms(24, 0, 0)
  }

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    for {task, _} <- @task_intervals, do: schedule_task(task)
    {:ok, %{}}
  end

  def handle_info(:purge_pass_cache, state) do
    count = Hamsat.Alerts.PassCache.purge()

    Logger.info("Purged #{count} passes from the ETS cache")

    schedule_task(:purge_pass_cache)
    {:noreply, state}
  end

  defp schedule_task(task) do
    Process.send_after(self(), task, @task_intervals[task])
  end
end
