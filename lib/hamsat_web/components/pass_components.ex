defmodule HamsatWeb.PassComponents do
  use HamsatWeb, :component

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass

  def pass_table(%{passes: _passes} = assigns) do
    ~H"""
    <table class="table w-full">
      <thead>
        <tr>
          <th title="Time of acquisition of signal">AOS (UTC)</th>
          <th title="Time until acquisition or loss of signal">AOS / LOS In</th>
          <th title="Satellite name">Sat</th>
          <th title="Satellite modulation">Mod</th>
          <th title="Duration of visible pass">Length</th>
          <th title="Max elevation during pass">Max El</th>
          <th colspan="3" title="Azimuth of satellite during pass">Az</th>
          <th title="Activation alerts">Alerts</th>
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
    <tr class={pass_table_row_class(@pass, @now)}>
      <td class="text-center whitespace-nowrap">
        <span class="mr-4"><%= date(@context, @pass.info.aos.datetime) %></span>
        <span class="mr-4"><%= time(@context, @pass.info.aos.datetime) %></span>
      </td>
      <td class="text-center"><%= next_aos_or_los_in(@now, @pass) %></td>
      <td class="text-center whitespace-nowrap"><%= pass_sat_name(@pass) %></td>
      <td class="text-center"><.sat_modulation_label sat={@pass.sat} /></td>
      <td class="text-center"><%= pass_duration(@pass) %></td>
      <td class="text-center"><%= pass_max_el(@pass) %></td>
      <td class="text-right"><%= pass_aos_direction(@pass) %></td>
      <td class="text-center">→</td>
      <td class="text-left"><%= pass_los_direction(@pass) %></td>
      <td class="text-center">
        <%= for alert <- @pass.alerts do %>
          <%= live_patch alert.callsign, to: Routes.alerts_path(HamsatWeb.Endpoint, :show, alert.id), class: "link mx-1" %>
        <% end %>
      </td>
      <td class="text-right pr-6 whitespace-nowrap">
        <%= if Alerts.show_create_alert_button?(@context, @pass, @now) do %>
          <%= link "Post an Alert", to: Routes.alerts_path(HamsatWeb.Endpoint, :new, pass: Pass.encode_hash(pass)), class: "link" %>
        <% end %>
        <%= if Alerts.show_edit_alert_button?(@context, @pass, @now) do %>
          <%= link "Modify Alert", to: Routes.alerts_path(HamsatWeb.Endpoint, :edit, Alerts.my_alert_during_pass(@context, @pass).id), class: "link" %>
        <% end %>
      </td>
    </tr>
    """
  end

  defp pass_table_row_class(pass, now) do
    case Pass.progression(pass, now) do
      :upcoming -> ""
      :in_progress -> "bg-yellow-100 text-yellow-800 font-semibold"
      :passed -> "text-gray-400"
    end
  end

  def sat_modulation_label(%{sat: _sat} = assigns) do
    ~H"""
    <span title={sat_modulation_title(@sat)} class={[sat_modulation_class(@sat), "text-xs rounded-full px-2 py-0.5 font-semibold text-gray-600 uppercase"]}>
      <%= sat_modulation_text(@sat) %>
    </span>
    """
  end

  defp sat_modulation_title(%{modulation: :fm}), do: "FM Modulation"
  defp sat_modulation_title(%{modulation: :linear}), do: "Linear (SSB/CW) Modulation"

  defp sat_modulation_text(%{modulation: :fm}), do: "FM"
  defp sat_modulation_text(%{modulation: :linear}), do: "Lin"

  defp sat_modulation_class(%{modulation: :fm}), do: "bg-amber-200 text-amber-600"
  defp sat_modulation_class(%{modulation: :linear}), do: "bg-emerald-200 text-emerald-600"

  defp next_aos_or_los_in(now, pass) do
    case pass_next_event_in(now, pass) do
      {:aos, duration} -> duration
      {:los, duration} -> "LOS in #{duration}"
    end
  end
end
