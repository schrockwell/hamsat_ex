defmodule HamsatWeb.API.AlertsController do
  use HamsatWeb, :controller

  alias Hamsat.Accounts.User
  alias Hamsat.Alerts
  alias Hamsat.Coord
  alias Hamsat.Passes
  alias Hamsat.Satellites
  alias Hamsat.Schemas.Alert

  action_fallback HamsatWeb.API.FallbackController

  plug :require_user when action in [:create, :update, :delete]

  def index(conn, _params) do
    alerts = Alerts.list_alerts(conn.assigns.context, date: :upcoming)
    render(conn, "index.json", alerts: alerts)
  end

  # Deprecated alias for index, kept for API compatibility
  def upcoming(conn, params), do: index(conn, params)

  def show(conn, %{"id" => id}) do
    with {:ok, alert} <- Alerts.get_alert(conn.assigns.context, id) do
      render(conn, "show.json", alert: alert)
    end
  end

  def create(conn, params) do
    context = conn.assigns.context

    with {:ok, sat} <- Satellites.fetch_satellite_by_number(params["satellite_number"]),
         {:ok, coord} <- parse_observer(params),
         {:ok, max_at} <- parse_max_at(params["max_at"]),
         {:ok, pass} <- Passes.find_pass_by_max_at(coord, sat, max_at),
         {:ok, form_params} <- build_form_params(params, sat),
         changeset = Alerts.change_alert(context, sat, pass, form_params),
         {:ok, alert} <- Alerts.create_alert(context, changeset) do
      alert = Alerts.get_alert!(context, alert.id)

      conn
      |> put_status(:created)
      |> put_resp_header("location", url(~p"/api/alerts/#{alert.id}"))
      |> render("show.json", alert: alert)
    end
  end

  # The pass identifies the alert, so the fields that select it are immutable
  @immutable_update_params ~w(satellite_number observer_lat observer_lon max_at)

  def update(conn, %{"id" => id} = params) do
    context = conn.assigns.context

    with {:ok, alert} <- fetch_owned_alert(context, id),
         :ok <- reject_immutable_params(params),
         coord = %Coord{lat: alert.observer_lat, lon: alert.observer_lon},
         {:ok, pass} <- Passes.find_pass_by_max_at(coord, alert.sat, alert.max_at),
         {:ok, form_params} <-
           build_form_params(Map.merge(base_params(alert), params), alert.sat),
         changeset = Alerts.change_alert(context, alert.sat, pass, form_params),
         {:ok, alert} <- Alerts.update_alert(alert, changeset) do
      render(conn, "show.json", alert: Alerts.get_alert!(context, alert.id))
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, alert} <- fetch_owned_alert(conn.assigns.context, id),
         {:ok, _alert} <- Alerts.delete_alert(alert) do
      send_resp(conn, :no_content, "")
    end
  end

  defp fetch_owned_alert(context, id) do
    with {:ok, alert} <- Alerts.get_alert(context, id) do
      if Alert.owned?(alert, context.user) do
        {:ok, alert}
      else
        {:error, :forbidden}
      end
    end
  end

  # Params from the alert being updated, overridden by whatever the request
  # provides.
  defp base_params(alert) do
    %{
      "callsign" => alert.callsign,
      "comment" => alert.comment,
      "mhz" => alert.mhz,
      "mhz_direction" => alert.mhz_direction,
      "mode" => alert.mode,
      "chat_enabled" => alert.chat_enabled,
      "observer_lat" => alert.observer_lat,
      "observer_lon" => alert.observer_lon,
      "grid_1" => Enum.at(alert.grids, 0),
      "grid_2" => Enum.at(alert.grids, 1),
      "grid_3" => Enum.at(alert.grids, 2),
      "grid_4" => Enum.at(alert.grids, 3)
    }
  end

  defp reject_immutable_params(params) do
    case Enum.filter(@immutable_update_params, &Map.has_key?(params, &1)) do
      [] -> :ok
      fields -> {:error, {:immutable_params, fields}}
    end
  end

  defp require_user(conn, _opts) do
    case conn.assigns.context.user do
      %User{} ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> put_view(HamsatWeb.API.ErrorView)
        |> render("401.json")
        |> halt()
    end
  end

  # AlertForm expects a satellite UUID and grid_1..grid_4 fields; the API
  # accepts a NORAD number and a grids array, so translate here.
  defp build_form_params(params, sat) do
    with {:ok, grid_params} <- grid_params(params) do
      form_params =
        params
        |> Map.merge(grid_params)
        |> Map.put("satellite_id", sat.id)
        |> default_mhz_direction()

      {:ok, form_params}
    end
  end

  # Matches the web UI's default so clients aren't forced to send a direction
  defp default_mhz_direction(%{"mhz_direction" => direction} = params) when direction not in [nil, ""],
    do: params

  defp default_mhz_direction(params), do: Map.put(params, "mhz_direction", "down")

  defp grid_params(%{"grids" => grids}) when is_list(grids) and length(grids) in 1..4 do
    # All four keys, so a shorter grids list clears the higher slots on update
    {:ok, Map.new(1..4, fn index -> {"grid_#{index}", Enum.at(grids, index - 1)} end)}
  end

  defp grid_params(%{"grids" => _grids}), do: {:error, :invalid_grids}

  # Let the changeset report the missing required grid
  defp grid_params(_params), do: {:ok, %{}}

  defp parse_observer(%{"observer_lat" => lat, "observer_lon" => lon}) do
    with {:ok, lat} <- parse_float(lat),
         {:ok, lon} <- parse_float(lon) do
      {:ok, %Coord{lat: lat, lon: lon}}
    end
  end

  defp parse_observer(_params), do: {:error, :invalid_observer}

  defp parse_float(value) when is_number(value), do: {:ok, value / 1}

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :invalid_observer}
    end
  end

  defp parse_float(_value), do: {:error, :invalid_observer}

  defp parse_max_at(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, :invalid_max_at}
    end
  end

  defp parse_max_at(_value), do: {:error, :invalid_max_at}
end
