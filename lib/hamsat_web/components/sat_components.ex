defmodule HamsatWeb.SatComponents do
  use HamsatWeb, :component

  alias Hamsat.Modulation
  alias Hamsat.Schemas.Alert

  @mini_plot_size 40
  @mini_plot_radius 18

  attr :coords, :list, required: true, doc: "list of %{az: ..., el: ...} sky coordinates"
  attr :class, :any, default: "h-8 w-8"

  def mini_polar_plot(assigns) do
    assigns = assign(assigns, :points, mini_polar_points(assigns.coords))

    ~H"""
    <svg viewBox="0 0 40 40" class={["block", @class]} aria-hidden="true">
      <line x1="20" y1="2" x2="20" y2="38" stroke="#e5e7eb" stroke-width="1" />
      <line x1="2" y1="20" x2="38" y2="20" stroke="#e5e7eb" stroke-width="1" />
      <circle cx="20" cy="20" r="18" fill="none" stroke="#d1d5db" stroke-width="1.5" />
      <%= if @points != "" do %>
        <polyline
          points={@points}
          fill="none"
          stroke="#2563eb"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        />
      <% end %>
    </svg>
    """
  end

  defp mini_polar_points(coords) do
    center = @mini_plot_size / 2

    coords
    |> Enum.filter(&(&1.el >= 0))
    |> Enum.map_join(" ", fn %{az: az, el: el} ->
      r = @mini_plot_radius * (90 - el) / 90
      rad = az * :math.pi() / 180
      "#{Float.round(center + r * :math.sin(rad), 1)},#{Float.round(center - r * :math.cos(rad), 1)}"
    end)
  end

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
