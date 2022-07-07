defmodule HamsatWeb.PageController do
  use HamsatWeb, :controller

  def about(conn, _params) do
    render(conn, "about.html")
  end
end
