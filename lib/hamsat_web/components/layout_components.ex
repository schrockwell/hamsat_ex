defmodule HamsatWeb.LayoutComponents do
  use HamsatWeb, :component

  def form_row(%{label: _label} = assigns) do
    extra_class = if assigns[:input?], do: "mt-1", else: ""

    assigns = assign(assigns, :label_class, ["w-48 text-right font-medium", extra_class])

    ~H"""
    <fieldset class="flex space-x-8">
      <div class={@label_class}><%= @label %></div>
      <div><%= render_slot @inner_block %></div>
    </fieldset>
    """
  end

  def filter_panel(assigns) do
    ~H"""
    <div class="w-full bg-gray-100 px-6 py-4 mx-auto border-b">
      <%= render_slot @inner_block %>
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
