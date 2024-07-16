defmodule HamsatWeb.SatComponents do
  use HamsatWeb, :component

  alias Hamsat.Modulation
  alias Hamsat.Schemas.Alert

  def sat_modulation_labels(%{sat: _sat} = assigns) do
    assigns = assign_new(assigns, :class, fn -> nil end)

    ~H"""
    <%= for modulation <- @sat.modulations do %>
      <.sat_modulation_label modulation={modulation} class={@class} />
    <% end %>
    """
  end

  def sat_modulation_label(%{modulation: _modulation} = assigns) do
    ~H"""
    <span
      title={Modulation.name(@modulation)}
      class={[
        assigns[:class],
        Modulation.css_class(@modulation),
        "text-xs px-1.5 py-0.5 font-semibold uppercase rounded inline-block"
      ]}
    >
      <%= Modulation.short_name(@modulation) %>
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
        <%= if @workability == :workable do %>
          <span class="text-xs font-medium bg-emerald-100 text-emerald-600 px-1.5 py-0.5 uppercase">Visible</span>
        <% end %>

        <%= if @event == :start, do: "in", else: "for" %>

        <%= hms(@seconds, coarse?: true) %>
        """

      :never ->
        ~H"passed"
    end
  end
end
