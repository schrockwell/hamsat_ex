defmodule HamsatWeb.APIDocsController do
  use HamsatWeb, :controller

  def index(conn, _params) do
    conn
    |> put_root_layout(false)
    |> put_layout(false)
    |> render("index.html")
  end

  def spec(conn, _params) do
    json(conn, HamsatWeb.APISpec.spec())
  end
end
