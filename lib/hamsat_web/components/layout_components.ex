defmodule HamsatWeb.LayoutComponents do
  use HamsatWeb, :component

  def filter_panel(assigns) do
    ~H"""
    <div class="bg-gray-100 border rounded-md px-6 py-3 mb-6">
      <%= render_slot @inner_block %>
    </div>
    """
  end
end
