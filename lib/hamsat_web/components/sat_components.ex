defmodule HamsatWeb.SatComponents do
  use HamsatWeb, :component

  alias Hamsat.Alerts.Pass
  alias Hamsat.Modulation
  alias Hamsat.Schemas.Alert

  def sat_modulation_label(%{sat: _sat} = assigns) do
    ~H"""
    <span
      title={Modulation.name(@sat)}
      class={[Modulation.css_class(@sat), "text-xs px-1.5 py-0.5 font-semibold uppercase rounded w-8 inline-block"]}
    >
      <%= Modulation.short_name(@sat) %>
    </span>
    """
  end

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
