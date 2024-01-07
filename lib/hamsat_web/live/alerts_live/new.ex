defmodule HamsatWeb.AlertsLive.New do
  use HamsatWeb, :live_view

  import Ecto.Changeset
  import HamsatWeb.LayoutComponents

  alias Hamsat.Alerts
  alias Hamsat.Coord
  alias Hamsat.Modulation
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.AlertForm
  alias HamsatWeb.LocationPicker

  state :alert, default: nil
  state :changeset
  state :page_title, default: "Post an Activation"
  state :params
  state :pass_list_params, default: nil
  state :passes, default: []
  state :sat

  def mount(%{"pass" => pass_hash}, _session, socket) do
    pass = Passes.get_pass_by_hash(socket.assigns.context, pass_hash)
    sat = pass.sat
    existing_alert = Alerts.my_alert_during_pass(socket.assigns.context, pass)

    if existing_alert do
      {:ok, redirect(socket, to: ~p"/alerts/#{existing_alert.id}/edit")}
    else
      {:ok,
       socket
       |> put_state(sat: sat)
       |> update_form(AlertForm.initial_params(socket.assigns.context, pass))
       |> use_recommended_grids()}
    end
  end

  def mount(%{"id" => alert_id}, _session, socket) do
    alert = Alerts.get_my_alert!(socket.assigns.context, alert_id)
    sat = alert.sat

    {:ok,
     socket
     |> put_state(sat: sat, alert: alert)
     |> update_form(AlertForm.initial_params(socket.assigns.context, alert))}
  end

  def mount(%{"sat" => sat_id}, _session, socket) do
    mount_with_sat(socket, Satellites.get_satellite_by_number!(sat_id))
  end

  def mount(_params, _session, socket) do
    mount_with_sat(socket, Satellites.first_satellite())
  end

  defp mount_with_sat(socket, sat) do
    {:ok,
     socket
     |> put_state(sat: sat)
     |> update_form(AlertForm.initial_params(socket.assigns.context, sat))
     |> use_recommended_grids()}
  end

  defp update_form(socket, params) do
    context = socket.assigns.context
    sat = get_sat(socket, params["satellite_id"])
    pass = get_pass(socket, params["pass_hash"])
    changeset = Alerts.change_alert(context, sat, pass, params)

    socket
    |> put_state(params: params, sat: sat, changeset: changeset)
    |> assign_passes()
  end

  defp get_sat(%{assigns: assigns} = socket, sat_id) do
    if assigns.sat.id == sat_id do
      socket.assigns.sat
    else
      Satellites.get_satellite!(sat_id)
    end
  end

  def get_pass(socket, pass_hash) do
    Enum.find(socket.assigns.passes, &(&1.hash == pass_hash))
  end

  def handle_emit(:on_map_clicked, _sender, {lat, lon}, socket) do
    params = Map.merge(socket.assigns.params, %{"observer_lat" => lat, "observer_lon" => lon})

    {:ok,
     socket
     |> update_form(params)
     |> use_recommended_grids()}
  end

  def handle_event("change", %{"alert_form" => params}, socket) do
    {:noreply, update_form(socket, params)}
  end

  def handle_event("submit", %{"alert_form" => params}, %{assigns: %{alert: nil}} = socket) do
    socket = update_form(socket, params)

    case Alerts.create_alert(socket.assigns.context, socket.assigns.changeset) do
      {:ok, alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created activation.")
         |> redirect(to: ~p"/alerts/#{alert.id}")}

      {:error, changeset} ->
        {:noreply, put_state(socket, changeset: changeset)}
    end
  end

  def handle_event("submit", %{"alert_form" => params}, %{assigns: %{alert: %Alert{} = alert}} = socket) do
    socket = update_form(socket, params)

    case Alerts.update_alert(alert, socket.assigns.changeset) do
      {:ok, alert} ->
        {:noreply,
         socket
         |> put_flash(:info, "Updated activation.")
         |> redirect(to: ~p"/alerts/#{alert.id}")}

      {:error, changeset} ->
        {:noreply, put_state(socket, changeset: changeset)}
    end
  end

  def handle_event("use-recommended-grids", _, socket) do
    {:noreply, use_recommended_grids(socket)}
  end

  def handle_event("delete", _, socket) do
    Alerts.delete_alert(socket.assigns.alert)

    {:noreply,
     socket
     |> put_flash(:info, "Activation deleted.")
     |> redirect(to: ~p"/passes")}
  end

  def handle_info({:fetch_passes, pass_list_params}, socket) do
    coord = %Coord{lat: pass_list_params.observer_lat, lon: pass_list_params.observer_lon}

    passes =
      Passes.list_passes(coord, socket.assigns.sat,
        starting:
          pass_list_params.date
          |> Timex.to_datetime(socket.assigns.context.timezone)
          |> Timex.beginning_of_day()
          |> Timex.to_datetime("Etc/UTC"),
        ending:
          pass_list_params.date
          |> Timex.to_datetime(socket.assigns.context.timezone)
          |> Timex.end_of_day()
          |> Timex.to_datetime("Etc/UTC")
      )

    {:noreply, put_state(socket, passes: passes)}
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

    recommended != [] and Enum.sort(recommended) != Enum.sort(actual)
  end

  defp mode_options(sat), do: Modulation.alert_options(sat.modulations)

  defp sat_freq_ranges(sat, changeset) do
    field =
      case selected_direction(changeset) do
        :up -> :uplinks
        :down -> :downlinks
      end

    modulations =
      changeset
      |> get_field(:mode)
      |> Modulation.list_by_alert_option()

    sat
    |> Map.fetch!(field)
    |> Enum.filter(fn subband -> subband.mode in modulations end)
    |> Enum.map(&subband_range/1)
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

    if pass_list_params != socket.assigns.pass_list_params and is_float(pass_list_params.observer_lat) and
         is_float(pass_list_params.observer_lon) do
      # This calculation can be slow, and we don't want to block the UI update, but also we want to make sure the
      # calculation happens serially, so let's immediately handle it in the next message
      send(self(), {:fetch_passes, pass_list_params})

      put_state(socket, pass_list_params: pass_list_params)
    else
      socket
    end
  end

  defp pass_options(context, passes) do
    Enum.map(passes, fn pass ->
      {time_span(context, pass.info.aos.datetime, pass.info.los.datetime), pass.hash}
    end)
  end
end
