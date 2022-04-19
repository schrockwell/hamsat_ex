defmodule HamsatWeb.PageController do
  use HamsatWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
