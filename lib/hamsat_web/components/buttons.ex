defmodule HamsatWeb.Buttons do
  use HamsatWeb, :component

  def nav_pill_button(%{to: _to} = assigns) do
    ~H"""
    <%= link to: @to, class: "px-4 py-2 rounded hover:bg-gray-200 transition-all" do %>
      <%= render_slot(@inner_block) %>
    <% end %>
    """
  end
end
