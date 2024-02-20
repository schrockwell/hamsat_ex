defmodule HamsatWeb.SatsLive.Show do
  use HamsatWeb, :live_view

  alias Hamsat.Satellites

  def mount(%{"number" => number}, _session, socket) do
    {:ok, assign(socket, sat: Satellites.get_satellite_by_number!(number))}
  end

  defp transponder_mode(:linear), do: "Linear Transponder (Inverting)"
  defp transponder_mode(:linear_non_inv), do: "Linear Transponder (Non-Inverting)"
  defp transponder_mode(:fm), do: "FM Transponder"
  defp transponder_mode(:digital), do: "Digital Transponder"
  defp transponder_mode(:cw_beacon), do: "CW Beacon"
  defp transponder_mode(:telemetry), do: "Telemetry"
  defp transponder_mode(other), do: to_string(other)

  defp transponder_status_badge(%{status: :active} = assigns) do
    ~H"""
    <span class="bg-green-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="check" type="mini" class="h-4 w-4" />Active
    </span>
    """
  end

  defp transponder_status_badge(%{status: :inactive} = assigns) do
    ~H"""
    <span class="bg-red-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="check" type="mini" class="h-4 w-4" /> Inactive
    </span>
    """
  end

  defp transponder_status_badge(%{status: :problems} = assigns) do
    ~H"""
    <span class="bg-orange-500 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="exclamation-triangle" type="mini" class="h-4 w-4" />Problems
    </span>
    """
  end

  defp transponder_status_badge(%{status: :unknown} = assigns) do
    ~H"""
    <span class="bg-red-600 text-white px-2 py-1 uppercase text-sm font-semibold flex items-center gap-1">
      <Heroicons.LiveView.icon name="question-mark-circle" type="mini" class="h-4 w-4" /> Unknown
    </span>
    """
  end
end
