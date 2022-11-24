defmodule HamsatWeb.SatComponents do
  use HamsatWeb, :component

  alias Hamsat.Alerts.Pass
  alias Hamsat.Schemas.Alert

  def sat_modulation_label(%{sat: _sat} = assigns) do
    ~H"""
    <span
      title={sat_modulation_title(@sat)}
      class={[sat_modulation_class(@sat), "text-xs px-1.5 py-0.5 font-semibold text-gray-600 uppercase"]}
    >
      <%= sat_modulation_text(@sat) %>
    </span>
    """
  end

  defp sat_modulation_title(%{modulation: :fm}), do: "FM Modulation"
  defp sat_modulation_title(%{modulation: :linear}), do: "Linear (SSB/CW) Modulation"
  defp sat_modulation_title(%{modulation: :digital}), do: "Digital Modulation"

  defp sat_modulation_text(%{modulation: :fm}), do: "FM"
  defp sat_modulation_text(%{modulation: :linear}), do: "Lin"
  defp sat_modulation_text(%{modulation: :digital}), do: "Dig"

  defp sat_modulation_class(%{modulation: :fm}), do: "bg-amber-100 text-amber-600"
  defp sat_modulation_class(%{modulation: :linear}), do: "bg-sky-100 text-sky-600"
  defp sat_modulation_class(%{modulation: :digital}), do: "bg-fuchsia-100 text-fuchsia-600"

  def alert_event_description(%{alert: _, now: _} = assigns) do
    case Alert.next_event(assigns.alert, assigns.now) do
      {workability, event, seconds} ->
        assigns =
          assign(assigns,
            workability: workability,
            event: event,
            seconds: seconds
          )

        ~H"""
        <%= if @workability == :workable and not @mine? do %>
          <span class="text-xs font-medium bg-emerald-100 text-emerald-600 px-1.5 py-0.5 uppercase">Workable</span>
        <% end %>

        <%= if @event == :start, do: "in", else: "for" %>

        <%= hms(@seconds) %>
        """

      :never ->
        ~H"passed"
    end
  end

  def pass_event_description(%{pass: _, now: _} = assigns) do
    case Pass.next_event(assigns.pass, assigns.now) do
      {:aos, duration} -> ~H"AOS in <%= hms(duration) %>"
      {:los, duration} -> ~H"LOS in <%= hms(duration) %>"
      :never -> ~H"passed"
    end
  end
end
