defmodule HamsatWeb.LayoutComponents do
  use HamsatWeb, :component

  def form_row(%{label: _label} = assigns) do
    extra_class = if assigns[:input?], do: "mt-1", else: ""

    assigns =
      assigns
      |> assign(:label_class, ["w-48 mb-1 md:mb-0 md:text-right font-medium", extra_class])
      |> assign_new(:class, fn -> nil end)

    ~H"""
    <fieldset class="md:flex md:space-x-8">
      <div class={@label_class}><%= @label %></div>
      <div class={@class}><%= render_slot(@inner_block) %></div>
    </fieldset>
    """
  end

  def filter_panel(assigns) do
    ~H"""
    <div class="w-full bg-gray-100 px-3 py-2 md:px-6 md:py-4 mx-auto border-b">
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def pill_picker(%{id: _id} = assigns) do
    ~H"""
    <div class="flex rounded-lg text-sm overflow-hidden">
      <%= for {value, label} <- @options do %>
        <button phx-click="select" phx-value-id={@id} phx-value-selected={value} class={pill_picker_class(value, @value)}>
          <%= label %>
        </button>
      <% end %>
    </div>
    """
  end

  defp pill_picker_class(value, value) do
    "px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white"
  end

  defp pill_picker_class(_value, _selected_value) do
    "px-4 py-2 bg-gray-200 hover:bg-gray-300 transition-all"
  end
end
