defmodule HamsatWeb.ContextHook do
  def on_mount(:default, _params, session, socket) do
    user = get_session_user(session)

    context = %Hamsat.Context{
      user: user,
      location: get_session_location(user, session)
    }

    {:cont, Phoenix.LiveView.assign(socket, :context, context)}
  end

  defp get_session_user(_session), do: nil

  defp get_session_location(nil, %{"lat" => lat, "lon" => lon} = _session) do
    %Hamsat.Coord{lat: lat, lon: lon}
  end

  defp get_session_location(nil, _session), do: nil
end
