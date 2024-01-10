defmodule HamsatWeb.PageView do
  use HamsatWeb, :view

  def date_header(assigns) do
    ~H"""
    <a href={"##{@date}"} name={@date}>
      <h2 class="text-h3 md:text-h2 mt-8 text-gray-400 mb-2 pb-1 border-b"><%= @date %></h2>
    </a>
    """
  end

  def new(assigns) do
    ~H"""
    <span class="inline-block text-xs bg-green-500 uppercase text-white rounded px-1 py-px font-semibold">
      New
    </span>
    """
  end

  def bug(assigns) do
    ~H"""
    <span class="inline-block text-xs bg-red-500 uppercase text-white rounded px-1 py-px font-semibold">
      Bug
    </span>
    """
  end

  def fix(assigns) do
    ~H"""
    <span class="inline-block text-xs bg-blue-500 uppercase text-white rounded px-1 py-px font-semibold">
      Fix
    </span>
    """
  end

  def sats(assigns) do
    ~H"""
    <span class="inline-block text-xs bg-amber-500 uppercase text-white rounded px-1 py-px font-semibold">
      Sats
    </span>
    """
  end
end
