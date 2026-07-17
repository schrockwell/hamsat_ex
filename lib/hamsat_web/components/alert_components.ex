defmodule HamsatWeb.AlertComponents do
  use HamsatWeb, :component

  def match_percentage(%{pct: _} = assigns) do
    assigns =
      assigns
      |> assign_new(:suffix, fn -> "" end)

    ~H"""
    <span class={["text-xs px-1.5 py-0.5 mr-1 uppercase", match_color_class(@pct)]}>
      <%= pct(@pct) %><%= @suffix %>
    </span>
    """
  end

  def match_percentage(%{alert: %{match: %{total: total}}} = assigns),
    do: match_percentage(Map.put(assigns, :pct, total))

  def match_percentage(assigns), do: ~H"<%= inspect(assigns) %>"

  defp match_color_class(total) do
    cond do
      total >= 0.75 -> "bg-emerald-100 text-emerald-700"
      total >= 0.25 -> "bg-amber-100 text-amber-600"
      true -> "bg-gray-200 text-gray-500"
    end
  end
end
