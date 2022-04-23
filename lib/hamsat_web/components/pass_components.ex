defmodule HamsatWeb.PassComponents do
  use HamsatWeb, :component

  def pass_table(%{passes: passes} = assigns) do
    ~H"""
    <table class="w-full">
      <tr>
        <th>AOS</th>
        <th>Sat</th>
        <th>Length</th>
        <th>Max El</th>
        <th colspan="3">Pass</th>
        <th>Alerts</th>
        <th></th>
      </tr>
      <%= render_slot @inner_block %>
    </table>
    """
  end

  def pass_table_row(%{pass: pass} = assigns) do
    ~H"""
    <tr>
      <td>
        <span class="mr-4"><%= date(@context, @pass.info.aos.datetime) %></span>
        <%= time(@context, @pass.info.aos.datetime) %>
      </td>
      <td class="text-center"><%= pass_sat_name(@pass) %></td>
      <td class="text-center"><%= pass_duration(@pass) %></td>
      <td class="text-center"><%= pass_max_el(@pass) %></td>
      <td class="text-right"><%= pass_aos_direction(@pass) %></td>
      <td class="text-center">→</td>
      <td><%= pass_los_direction(@pass) %></td>
      <td><%= length(@pass.alerts) %></td>
      <td class="text-right"><%= link "Create an Alert", to: "#" %></td>
    </tr>
    """
  end
end
