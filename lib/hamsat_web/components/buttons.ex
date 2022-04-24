defmodule HamsatWeb.Buttons do
  use HamsatWeb, :component

  def nav_pill_button(%{to: _to} = assigns) do
    ~H"""
    <%= link to: @to, class: [nav_pill_button_class(assigns), "px-4 py-2 rounded hover:bg-gray-500 transition-all"] do %>
      <%= render_slot(@inner_block) %>
    <% end %>
    """
  end

  defp nav_pill_button_class(%{conn: conn, active: %Regex{} = active}) do
    if Regex.match?(active, conn.request_path) do
      "underline underline-offset-4"
    else
      ""
    end
  end
end
