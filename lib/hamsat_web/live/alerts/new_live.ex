defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  alias Hamsat.Alerts
  alias Hamsat.Grid

  def mount(%{"pass" => pass_hash}, _, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)

    socket =
      socket
      |> assign(:pass, pass)
      |> assign(:sat, pass.sat)
      |> assign(:grid, Grid.encode!(pass.observer.latitude_deg, pass.observer.longitude_deg, 6))
      |> assign_mode_options()
      |> assign_alert_changeset()

    {:ok, socket}
  end

  def handle_event("submit", %{"alert" => alert_params}, socket) do
    case Alerts.create_alert(socket.assigns.context, socket.assigns.pass, alert_params) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created an alert.")
         |> push_redirect(to: Routes.passes_path(socket, :index))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp form_row(%{label: _label} = assigns) do
    extra_class = if assigns[:input?], do: "mt-1", else: ""

    assigns = assign(assigns, :label_class, ["w-48 text-right font-medium", extra_class])

    ~H"""
    <fieldset class="flex space-x-8">
      <div class={@label_class}><%= @label %></div>
      <div><%= render_slot @inner_block %></div>
    </fieldset>
    """
  end

  defp assign_alert_changeset(socket, params \\ %{}) do
    assign(
      socket,
      :changeset,
      Alerts.change_alert(socket.assigns.context, socket.assigns.pass, params)
    )
  end

  defp assign_mode_options(socket) do
    assign(socket, :mode_options, Alerts.mode_options(socket.assigns.sat))
  end

  defp sat_downlink_ranges(sat) do
    sat.downlinks
    |> Enum.map(fn
      %{lower_mhz: mhz, upper_mhz: mhz} ->
        "#{mhz} MHz"

      downlink ->
        "#{downlink.lower_mhz} – #{downlink.upper_mhz} MHz"
    end)
    |> Enum.join(", ")
  end
end
