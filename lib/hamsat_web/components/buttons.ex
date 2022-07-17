defmodule HamsatWeb.Buttons do
  use HamsatWeb, :component

  def nav_pill_button(%{conn: _conn, to: _to} = assigns) do
    link_opts =
      assigns
      |> Map.take([:to, :method])
      |> Map.put(:class, [nav_pill_button_class(assigns), "btn-nav"])
      |> Map.to_list()

    assigns = assign(assigns, :link_opts, link_opts)

    ~H"""
    <%= link @link_opts do %>
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

  defp nav_pill_button_class(_), do: ""
end
