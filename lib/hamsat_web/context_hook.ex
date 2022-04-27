defmodule HamsatWeb.ContextHook do
  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  def on_mount(:default, _params, session, socket) do
    user = get_session_user(session) || :guest

    context = %Hamsat.Context{
      user: user,
      location: get_session_location(user, session)
    }

    {:cont, Phoenix.LiveView.assign(socket, :context, context)}
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
