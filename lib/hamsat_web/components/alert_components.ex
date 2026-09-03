defmodule HamsatWeb.AlertComponents do
  use HamsatWeb, :component

  def match_percentage(%{pct: _} = assigns) do
    assigns =
      assigns
      |> assign_new(:suffix, fn -> "" end)

    ~H"""
    <span class={match_class(@pct)}><%= pct(@pct) %><%= @suffix %></span>
    """
  end

  def match_percentage(%{alert: %{match: %{total: total}}} = assigns),
    do: match_percentage(Map.put(assigns, :pct, total))

  def match_percentage(assigns), do: ~H""

  @doc """
  Marks a test alert (created via the API). Only the owner ever sees a test
  alert, so this is a reminder rather than a warning.
  """
  attr :alert, Hamsat.Schemas.Alert, required: true

  def test_badge(%{alert: %{is_test: true}} = assigns) do
    ~H"""
    <span class={test_badge_class()} title={test_badge_title()}>Test</span>
    """
  end

  def test_badge(assigns), do: ~H""

  # See match_class/1 for why these live in functions
  defp test_badge_class,
    do: "text-xs px-1.5 py-0.5 uppercase font-medium bg-purple-100 text-purple-700 align-middle"

  defp test_badge_title, do: "Test activation, created via the API. Only you can see it."

  # Kept as a function so the badge span stays on one line in the template —
  # a line break inside the span renders as visible whitespace in the label
  defp match_class(pct) do
    ["text-xs px-1.5 py-0.5 mr-1 uppercase font-medium", match_color_class(pct)]
  end

  @doc "Badge colors for a match score: emerald for good, amber for fair, gray for poor."
  def match_color_class(total) do
    cond do
      total >= 0.75 -> "bg-emerald-100 text-emerald-600"
      total >= 0.25 -> "bg-amber-100 text-amber-600"
      true -> "bg-gray-200 text-gray-500"
    end
  end
end
