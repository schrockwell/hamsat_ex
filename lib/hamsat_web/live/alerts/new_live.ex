defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias Hamsat.Grid
  alias Hamsat.Modulation

  state :alert
  state :changeset
  state :grid
  state :mode_options
  state :page_title
  state :pass
  state :sat

  def mount(%{"pass" => pass_hash}, _, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)
    existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)

    if existing_alert do
      {:ok, redirect(socket, to: Routes.alerts_path(socket, :edit, existing_alert.id))}
    else
      socket =
        socket
        |> put_state(
          sat: pass.sat,
          alert: nil,
          changeset: Alerts.change_new_alert(socket.assigns.context, pass, %{}),
          page_title: "New Activation",
          pass: pass
        )

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
      |> put_state(
        sat: alert.sat,
        alert: alert,
        changeset: Alerts.change_alert(alert),
        page_title: "Edit Activation",
        pass: pass
      )

    {:ok, socket}
  end

  def handle_event("change", %{"alert" => alert_params}, %{assigns: %{live_action: :new}} = socket) do
    {:noreply,
     assign(socket, :changeset, Alerts.change_new_alert(socket.assigns.context, socket.assigns.pass, alert_params))}
  end

  def handle_event("change", %{"alert" => alert_params}, %{assigns: %{live_action: :edit}} = socket) do
    {:noreply, assign(socket, :changeset, Alerts.change_alert(socket.assigns.alert, alert_params))}
  end

  def handle_event(
        "submit",
        %{"alert" => alert_params},
        %{assigns: %{live_action: :new}} = socket
      ) do
    case Alerts.create_alert(socket.assigns.context, socket.assigns.pass, alert_params) do
      {:ok, alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created an alert.")
         |> redirect(to: Routes.alerts_path(socket, :show, alert.id))}

      {:error, changeset} ->
        {:noreply, put_state(socket, changeset: changeset)}
    end
  end

  def handle_event(
        "submit",
        %{"alert" => alert_params},
        %{assigns: %{live_action: :edit}} = socket
      ) do
    case Alerts.update_alert(socket.assigns.alert, alert_params) do
      {:ok, alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Updated an alert.")
         |> redirect(to: Routes.alerts_path(socket, :show, alert.id))}

      {:error, changeset} ->
        {:noreply, put_state(socket, changeset: changeset)}
    end
  end

  def handle_event("delete", _, socket) do
    Alerts.delete_alert(socket.assigns.alert)

    {:noreply,
     socket
     |> put_flash(:info, "Activation deleted.")
     |> redirect(to: Routes.passes_path(socket, :index))}
  end

  @react to: :sat
  def put_mode_options(socket) do
    put_state(socket, mode_options: Modulation.alert_options(socket.assigns.sat))
  end

  @react to: :pass
  def put_grid(socket) do
    put_state(socket,
      grid:
        Grid.encode!(
          socket.assigns.pass.observer.latitude_deg,
          socket.assigns.pass.observer.longitude_deg,
          6
        )
    )
  end

  defp sat_freq_ranges(sat, changeset) do
    field =
      case selected_direction(changeset) do
        :up -> :uplinks
        :down -> :downlinks
      end

    sat
    |> Map.fetch!(field)
    |> Enum.map(fn
      %{lower_mhz: mhz, upper_mhz: mhz} ->
        "#{mhz(mhz, 3)} MHz"

      downlink ->
        "#{mhz(downlink.lower_mhz, 3)} – #{mhz(downlink.upper_mhz, 3)} MHz"
    end)
    |> Enum.join(", ")
  end

  defp action_verb(:new), do: "Post"
  defp action_verb(:edit), do: "Update"

  defp selected_direction(changeset) do
    Ecto.Changeset.get_field(changeset, :mhz_direction)
  end
end
