defmodule HamsatWeb.APIPlug do
  @behaviour Plug

  import Plug.Conn

  @require_api_key Application.compile_env(:hamsat, :authenticate_api)

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    conn = assign(conn, :context, %Hamsat.Context{})

    if @require_api_key do
      authenticate(conn)
    else
      conn
    end
  end

  defp authenticate(conn) do
    if api_key = get_api_key(conn) do
      assign(conn, :api_key, api_key)
    else
      conn
      |> put_status(:unauthorized)
      |> Phoenix.Controller.json(%{error: "Unauthorized"})
      |> halt()
    end
  end

  defp get_api_key(conn) do
    with ["Bearer " <> id | _] <- get_req_header(conn, "authorization"),
         {:ok, uuid} <- parse_uuid(id) do
      Hamsat.Accounts.get_enabled_api_key(uuid)
    else
      _ -> nil
    end
  end

  defp parse_uuid(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      _ -> :error
    end
  end
end
