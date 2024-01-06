defmodule HamsatWeb.PageView do
  use HamsatWeb, :view

  def date_header(assigns) do
    ~H"""
    <a href={"##{@date}"} name={@date}>
      <h2 class="text-h3 md:text-h2 mt-8 text-gray-400 mb-2 pb-1 border-b"><%= @date %></h2>
    </a>
    """
  end
end
