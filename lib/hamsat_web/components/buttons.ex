defmodule HamsatWeb.Buttons do
  use HamsatWeb, :component

  def nav_pill_button(assigns) do
    link_assigns =
      assigns
      |> Map.take([:navigate, :href, :method])
      |> Map.put(:class, [nav_pill_button_class(assigns), "btn-nav"])
      |> Map.to_list()

    assigns = assign(assigns, :link_assigns, link_assigns)

    ~H"""
    <.link {@link_assigns}>
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  defp nav_pill_button_class(%{active: true}), do: "underline underline-offset-4"
  defp nav_pill_button_class(_), do: ""
end
