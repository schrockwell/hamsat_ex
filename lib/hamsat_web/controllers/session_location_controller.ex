defmodule HamsatWeb.SessionLocationController do
  use HamsatWeb, :controller

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  def update(conn, %{"form" => %{"lat" => lat, "lon" => lon}} = params) do
    with {lat, _} <- Float.parse(lat),
         {lon, _} <- Float.parse(lon) do
      conn
      |> put_session("lat", lat)
      |> put_session("lon", lon)
      |> maybe_update_user_home_location(%{home_lat: lat, home_lon: lon})
      |> put_flash(:info, "Location updated to #{Hamsat.Grid.encode!({lat, lon}, 6)}.")
      |> redirect(to: params["redirect"] || ~p"/location")
    else
      _ ->
        conn
        |> put_flash(:error, "Location not updated")
        |> redirect(to: ~p"/location")
    end
  end

  defp maybe_update_user_home_location(%{assigns: %{current_user: %User{} = user}} = conn, attrs) do
    {:ok, _user} = Accounts.update_home_location(user, attrs)
    conn
  end

  defp maybe_update_user_home_location(conn, _attrs), do: conn
end
