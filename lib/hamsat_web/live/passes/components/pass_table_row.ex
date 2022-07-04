defmodule HamsatWeb.Passes.Components.PassTableRow do
  use HamsatWeb, :live_component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok,
     socket
     |> assign(:class, pass_table_row_class(socket.assigns.pass, socket.assigns.now))
     |> assign(:next_aos, next_aos_or_los_in(socket.assigns.now, socket.assigns.pass))}
  end

  defp pass_table_row_class(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming -> ""
      :in_progress -> "bg-yellow-100 text-yellow-800 font-semibold"
      :passed -> "text-gray-400"
    end
  end

  def sat_modulation_label(%{sat: _sat} = assigns) do
    ~H"""
    <span title={sat_modulation_title(@sat)} class={[sat_modulation_class(@sat), "text-xs rounded-full px-2 py-0.5 font-semibold text-gray-600 uppercase"]}>
      <%= sat_modulation_text(@sat) %>
    </span>
    """
  end

  defp sat_modulation_title(%{modulation: :fm}), do: "FM Modulation"
  defp sat_modulation_title(%{modulation: :linear}), do: "Linear (SSB/CW) Modulation"

  defp sat_modulation_text(%{modulation: :fm}), do: "FM"
  defp sat_modulation_text(%{modulation: :linear}), do: "Lin"

  defp sat_modulation_class(%{modulation: :fm}), do: "bg-amber-200 text-amber-600"
  defp sat_modulation_class(%{modulation: :linear}), do: "bg-emerald-200 text-emerald-600"

  defp next_aos_or_los_in(now, pass) do
    case pass_next_event_in(now, pass) do
      {:aos, duration} -> duration
      {:los, duration} -> "LOS in #{duration}"
    end
  end
end
