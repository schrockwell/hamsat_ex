defmodule Hamsat.Context do
  defstruct user: :guest, location: nil, timezone: "Etc/UTC", time_format: "24h"

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  def from_session(session) do
    if user = get_session_user(session) do
      from_user(user)
    else
      %Hamsat.Context{
        user: :guest,
        location: get_session_location(session),
        timezone: get_session_timezone(session),
        time_format: get_session_time_format(session)
      }
    end
  end

  def from_user(%User{} = user) do
    %Hamsat.Context{
      user: user,
      location: %Hamsat.Coord{lat: user.home_lat, lon: user.home_lon},
      timezone: user.timezone,
      time_format: user.time_format
    }
  end

  defp get_session_user(session) do
    if user_token = session["user_token"] do
      Accounts.get_user_by_session_token(user_token)
    end
  end

  defp get_session_location(%{"lat" => lat, "lon" => lon})
       when is_float(lat) and is_float(lon) do
    %Hamsat.Coord{lat: lat, lon: lon}
  end

  defp get_session_location(_session), do: nil

  defp get_session_timezone(%{"timezone" => timezone}) when is_binary(timezone) do
    timezone
  end

  defp get_session_timezone(_session), do: "Etc/UTC"

  defp get_session_time_format(%{"time_format" => time_format}) when is_binary(time_format),
    do: time_format

  defp get_session_time_format(_session), do: "24h"
end
