defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias Hamsat.Grid

  def mount(%{"pass" => pass_hash}, _, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)
    existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)

    if existing_alert do
      {:ok, redirect(socket, to: Routes.alerts_path(socket, :edit, existing_alert.id))}
    else
      socket =
        socket
        |> assign(:page_title, "New Activation")
        |> assign(:pass, pass)
        |> assign(:sat, pass.sat)
        |> assign(:grid, Grid.encode!(pass.observer.latitude_deg, pass.observer.longitude_deg, 6))
        |> assign_mode_options()
        |> assign_new_alert_changeset()

      {:ok, socket}
    end
  end

  def mount(%{"id" => alert_id}, _, socket) do
    # existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)
    # pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)

    alert = Alerts.get_my_alert!(socket.assigns.context, alert_id)
    pass = Alerts.get_pass_by_alert(alert)

    socket =
      socket
      |> assign(:page_title, "Edit Activation")
      |> assign(:alert, alert)
      |> assign(:pass, pass)
      |> assign(:sat, alert.sat)
      |> assign(:grid, Grid.encode!(pass.observer.latitude_deg, pass.observer.longitude_deg, 6))
      |> assign_mode_options()
      |> assign_edit_alert_changeset(alert)

    {:ok, socket}
  end

  def handle_event(
        "submit",
        %{"alert" => alert_params},
        %{assigns: %{live_action: :new}} = socket
      ) do
    case Alerts.create_alert(socket.assigns.context, socket.assigns.pass, alert_params) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created an alert.")
         |> redirect(to: Routes.passes_path(socket, :index))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event(
        "submit",
        %{"alert" => alert_params},
        %{assigns: %{live_action: :edit}} = socket
      ) do
    case Alerts.update_alert(socket.assigns.alert, alert_params) do
      {:ok, _alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Updated an alert.")
         |> redirect(to: Routes.passes_path(socket, :index))}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", _, socket) do
    Alerts.delete_alert(socket.assigns.alert)

    {:noreply,
     socket
     |> put_flash(:info, "Activation deleted.")
     |> redirect(to: Routes.passes_path(socket, :index))}
  end

  defp assign_new_alert_changeset(socket, params \\ %{}) do
    assign(
      socket,
      :changeset,
      Alerts.change_new_alert(socket.assigns.context, socket.assigns.pass, params)
    )
  end

  defp assign_edit_alert_changeset(socket, alert, params \\ %{}) do
    assign(
      socket,
      :changeset,
      Alerts.change_alert(alert, params)
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

  defp action_verb(:new), do: "Post"
  defp action_verb(:edit), do: "Update"
end
