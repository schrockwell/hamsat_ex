defmodule HamsatWeb.ContextHook do
  def on_mount(:default, _params, session, socket) do
    context = %Hamsat.Context{
      user: get_session_user(session),
      observer: get_session_observer(session)
    }

    {:cont, Phoenix.LiveView.assign(socket, :context, context)}
  end

  defp get_session_user(_session), do: nil

  defp get_session_observer(%{"observer_lat" => lat, "observer_lon" => lon}) do
    Observer.create_from(lat, lon, 0)
  end

  defp get_session_observer(_session), do: Observer.create_from(0, 0, 0)
end
