defmodule Hamsat.Context do
  defstruct user: :guest, location: nil, timezone: "Etc/UTC"

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  def from_session(session) do
    user = get_session_user(session) || :guest

    %Hamsat.Context{
      user: user,
      location: get_session_location(user, session)
    }
  end

  defp get_session_user(session) do
    if user_token = session["user_token"] do
      Accounts.get_user_by_session_token(user_token)
    end
  end

  defp get_session_location(%User{} = user, _session) do
    %Hamsat.Coord{lat: user.home_lat, lon: user.home_lon}
  end

  defp get_session_location(:guest, %{"lat" => lat, "lon" => lon} = _session)
       when is_float(lat) and is_float(lon) do
    %Hamsat.Coord{lat: lat, lon: lon}
  end

  defp get_session_location(_user, _session), do: nil
end
