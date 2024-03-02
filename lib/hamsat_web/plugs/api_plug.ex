defmodule HamsatWeb.APIPlug do
  @behaviour Plug

  import Plug.Conn

  alias Hamsat.Accounts
  alias Hamsat.Context

  @require_api_key Application.compile_env(:hamsat, :authenticate_api)

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    conn = assign(conn, :context, %Context{})

    if @require_api_key do
      authenticate_api_key(conn)
    else
      authenticate_feed_key(conn)
    end
  end

  defp authenticate_api_key(conn) do
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
      Accounts.get_enabled_api_key(uuid)
    else
      _ -> nil
    end
  end

  defp authenticate_feed_key(conn) do
    if user = get_user_by_feed_key(conn) do
      assign(conn, :context, Context.from_user(user))
    else
      # Guest user is okay
      conn
    end
  end

  defp get_user_by_feed_key(conn) do
    with ["Bearer " <> id | _] <- get_req_header(conn, "authorization"),
         {:ok, uuid} <- parse_uuid(id) do
      Accounts.get_user_by_feed_key(uuid)
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
