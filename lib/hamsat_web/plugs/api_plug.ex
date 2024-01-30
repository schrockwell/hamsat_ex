defmodule HamsatWeb.APIPlug do
  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(_), do: []

  @impl Plug
  def call(conn, _) do
    if api_key = get_api_key(conn) do
      conn
      |> assign(:api_key, api_key)
      |> assign(:context, %Hamsat.Context{})
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
