defmodule HamsatWeb.Alerts.NewLive do
  use HamsatWeb, :live_view

  import Ecto.Changeset
  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias Hamsat.Alerts.Pass
  alias Hamsat.Coord
  alias Hamsat.Grid
  alias Hamsat.Modulation
  alias Hamsat.Satellites
  alias Hamsat.Schemas.AlertForm
  alias HamsatWeb.LocationPicker

  state :alert_form, default: %AlertForm{}
  state :changeset
  state :page_title, default: "Post an Activation"
  state :params
  state :pass_list_params, default: nil
  state :passes, default: []
  state :sat

  def mount(%{"pass" => pass_hash}, _session, socket) do
    pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)
    sat = pass.sat
    existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)

    if existing_alert do
      {:ok, redirect(socket, to: Routes.alerts_path(socket, :edit, existing_alert.id))}
    else
      {:ok,
       socket
       |> assign(:sat, sat)
       |> update_form(AlertForm.initial_params(socket.assigns.context, pass))
       |> use_recommended_grids()}
    end
  end

  def mount(_params, _session, socket) do
    sat = Satellites.first_satellite()

    {:ok,
     socket
     |> assign(:sat, sat)
     |> update_form(AlertForm.initial_params(socket.assigns.context, sat))
     |> use_recommended_grids()}
  end

  defp update_form(socket, params) do
    socket
    |> assign(:params, params)
    |> assign(:changeset, AlertForm.changeset(socket.assigns.alert_form, params))
    |> assign_sat()
    |> assign_passes()
  end

  defp assign_sat(%{assigns: assigns} = socket) do
    sat_id = get_field(assigns.changeset, :satellite_id)

    if assigns.sat.id == sat_id do
      socket
    else
      assign(socket, :sat, Satellites.get_satellite!(sat_id))
    end
  end

  def handle_emit(:on_map_clicked, _sender, {lat, lon}, socket) do
    params = Map.merge(socket.assigns.params, %{"observer_lat" => lat, "observer_lon" => lon})

    {:ok,
     socket
     |> update_form(params)
     |> use_recommended_grids()}
  end

  def handle_event("change", %{"alert_form" => params}, %{assigns: %{live_action: :new}} = socket) do
    {:noreply, update_form(socket, params)}
  end

  def handle_event("use-recommended-grids", _, socket) do
    {:noreply, use_recommended_grids(socket)}
  end

  defp use_recommended_grids(socket) do
    grid_params =
      case AlertForm.recommended_grids(socket.assigns.changeset) do
        [grid_1] ->
          %{"grid_1" => grid_1, "grid_2" => nil, "grid_3" => nil, "grid_4" => nil}

        [grid_1, grid_2] ->
          %{"grid_1" => grid_1, "grid_2" => grid_2, "grid_3" => nil, "grid_4" => nil}

        [grid_1, grid_2, grid_3, grid_4] ->
          %{"grid_1" => grid_1, "grid_2" => grid_2, "grid_3" => grid_3, "grid_4" => grid_4}

        _ ->
          %{}
      end

    update_form(socket, Map.merge(socket.assigns.params, grid_params))
  end

  defp show_recommended_grids?(changeset) do
    recommended = AlertForm.recommended_grids(changeset)

    actual =
      [:grid_1, :grid_2, :grid_3, :grid_4]
      |> Enum.map(&get_field(changeset, &1))
      |> Enum.reject(&is_nil/1)

    Enum.sort(recommended) != Enum.sort(actual)
  end

  defp mode_options(sat), do: Modulation.alert_options(sat)

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
    get_field(changeset, :mhz_direction)
  end

  defp assign_passes(socket) do
    pass_list_params = %{
      sat_id: socket.assigns.sat.id,
      date: get_field(socket.assigns.changeset, :pass_filter_date),
      observer_lat: get_field(socket.assigns.changeset, :observer_lat),
      observer_lon: get_field(socket.assigns.changeset, :observer_lon)
    }

    if pass_list_params == socket.assigns.pass_list_params do
      socket
    else
      parent = self()

      coord = %Coord{lat: pass_list_params.observer_lat, lon: pass_list_params.observer_lon}

      passes =
        Alerts.list_passes(coord, socket.assigns.sat,
          starting: pass_list_params.date |> Timex.to_datetime() |> Timex.beginning_of_day(),
          ending: pass_list_params.date |> Timex.to_datetime() |> Timex.end_of_day()
        )

      assign(socket, passes: passes, pass_list_params: pass_list_params)
    end
  end

  defp pass_options(passes) do
    Enum.map(passes, fn pass ->
      {time_span(pass.info.aos.datetime, pass.info.los.datetime), pass.hash}
    end)
  end

  # def mount(%{"pass" => pass_hash}, _, socket) do
  #   pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)
  #   existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)

  #   if existing_alert do
  #     {:ok, redirect(socket, to: Routes.alerts_path(socket, :edit, existing_alert.id))}
  #   else
  #     socket =
  #       socket
  #       |> put_state(
  #         sat: pass.sat,
  #         sat_options: Satellites.list_satellite_options(),
  #         alert: nil,
  #         changeset: Alerts.change_new_alert(socket.assigns.context, pass, %{}),
  #         page_title: "New Activation",
  #         pass: pass
  #       )

  #     {:ok, socket}
  #   end
  # end

  # def mount(%{"id" => alert_id}, _, socket) do
  #   # existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)
  #   # pass = Alerts.get_pass_by_hash(socket.assigns.context, pass_hash)

  #   alert = Alerts.get_my_alert!(socket.assigns.context, alert_id)
  #   pass = Alerts.get_pass_by_alert(alert)

  #   socket =
  #     socket
  #     |> put_state(
  #       sat: alert.sat,
  #       sat_options: Satellites.list_satellite_options(),
  #       alert: alert,
  #       changeset: Alerts.change_alert(alert),
  #       page_title: "Edit Activation",
  #       pass: pass
  #     )

  #   {:ok, socket}
  # end

  # def handle_event(
  #       "submit",
  #       %{"alert" => alert_params},
  #       %{assigns: %{live_action: :new}} = socket
  #     ) do
  #   case Alerts.create_alert(socket.assigns.context, socket.assigns.pass, alert_params) do
  #     {:ok, alert} ->
  #       {:noreply,
  #        socket
  #        |> put_flash(:info, "Created an alert.")
  #        |> redirect(to: Routes.alerts_path(socket, :show, alert.id))}

  #     {:error, changeset} ->
  #       {:noreply, put_state(socket, changeset: changeset)}
  #   end
  # end

  # def handle_event(
  #       "submit",
  #       %{"alert" => alert_params},
  #       %{assigns: %{live_action: :edit}} = socket
  #     ) do
  #   case Alerts.update_alert(socket.assigns.alert, alert_params) do
  #     {:ok, alert} ->
  #       {:noreply,
  #        socket
  #        |> put_flash(:info, "Updated an alert.")
  #        |> redirect(to: Routes.alerts_path(socket, :show, alert.id))}

  #     {:error, changeset} ->
  #       {:noreply, put_state(socket, changeset: changeset)}
  #   end
  # end

  # def handle_event("delete", _, socket) do
  #   Alerts.delete_alert(socket.assigns.alert)

  #   {:noreply,
  #    socket
  #    |> put_flash(:info, "Activation deleted.")
  #    |> redirect(to: Routes.passes_path(socket, :index))}
  # end
end
