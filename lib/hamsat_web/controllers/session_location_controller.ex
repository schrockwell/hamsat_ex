defmodule HamsatWeb.SessionLocationController do
  use HamsatWeb, :controller

  def update(conn, %{"lat" => lat, "lon" => lon}) do
    with {lat, _} <- Float.parse(lat),
         {lon, _} <- Float.parse(lon) do
      conn
      |> put_session("lat", lat)
      |> put_session("lon", lon)
      |> put_flash(:info, "Location updated")
      |> redirect(to: Routes.location_path(conn, :edit))
    else
      _ ->
        conn
        |> put_flash(:error, "Location not updated")
        |> redirect(to: Routes.location_path(conn, :edit))
    end
  end
end
