defmodule HamsatWeb.AdminsOnlyPlug do
  import Plug.Conn

  @behaviour Plug

  @admin_emails ["rockwell@schrock.me"]

  def init(_), do: []

  def call(%{assigns: %{context: %{user: %{email: email}}}} = conn, _)
      when email in @admin_emails do
    conn
  end

  def call(conn, _) do
    conn
    |> Phoenix.Controller.put_root_layout(false)
    |> Phoenix.Controller.render(HamsatWeb.ErrorView, :"404")
    |> halt()
  end
end
