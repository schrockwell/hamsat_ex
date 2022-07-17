defmodule HamsatWeb.AlertComponents do
  use HamsatWeb, :component

  def match_percentage(%{alert: %{match: nil}} = assigns), do: ~H""

  def match_percentage(%{alert: _} = assigns) do
    ~H"""
      <span class="text-xs px-1.5 py-0.5 bg-gray-200 mr-1"><%= pct(@alert.match.total) %></span>
    """
  end
end
