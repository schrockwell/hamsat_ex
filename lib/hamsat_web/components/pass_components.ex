defmodule HamsatWeb.PassComponents do
  use HamsatWeb, :component

  def pass_table(%{passes: passes} = assigns) do
    ~H"""
    <table class="table w-full">
      <thead>
        <tr>
          <th>AOS (UTC)</th>
          <th>AOS In</th>
          <th>Sat</th>
          <th>Mod</th>
          <th>Length</th>
          <th>Max El</th>
          <th colspan="3">Pass</th>
          <th>Alerts</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <%= render_slot @inner_block %>
      </tbody>
    </table>
    """
  end

  def pass_table_row(%{pass: pass} = assigns) do
    ~H"""
    <tr>
      <td class="text-center">
        <span class="mr-4"><%= date(@context, @pass.info.aos.datetime) %></span>
        <span class="mr-4"><%= time(@context, @pass.info.aos.datetime) %></span>
      </td>
      <td class="text-center"><%= pass_aos_in(@now, @pass) %></td>
      <td class="text-center"><%= pass_sat_name(@pass) %></td>
      <td class="text-center"><.sat_modulation_label sat={@pass.sat} /></td>
      <td class="text-center"><%= pass_duration(@pass) %></td>
      <td class="text-center"><%= pass_max_el(@pass) %></td>
      <td class="text-right"><%= pass_aos_direction(@pass) %></td>
      <td class="text-center">→</td>
      <td class="text-left"><%= pass_los_direction(@pass) %></td>
      <td class="text-center"><%= length(@pass.alerts) %></td>
      <td class="text-center"><%= link "Create an Alert", to: "#" %></td>
    </tr>
    """
  end

  def sat_modulation_label(%{sat: sat} = assigns) do
    assigns = assign(assigns, :text, sat_modulation_text(sat))

    ~H"""
    <span class="text-xs rounded px-2 py-1 font-semibold bg-gray-200 uppercase"><%= @text %></span>
    """
  end

  defp sat_modulation_text(%{modulation: :fm}), do: "FM"
  defp sat_modulation_text(%{modulation: :linear}), do: "Lin"
end
