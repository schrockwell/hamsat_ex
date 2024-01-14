defmodule HamsatWeb.PageController do
  use HamsatWeb, :controller

  def about(conn, _params) do
    conn
    |> assign(:page_title, "About")
    |> render("about.html")
  end

  def changelog(conn, _params) do
    conn
    |> assign(:page_title, "Changelog")
    |> render("changelog.html")
  end
end
