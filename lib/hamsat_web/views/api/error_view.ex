defmodule HamsatWeb.API.ErrorView do
  use HamsatWeb, :view

  def render("401.json", _assigns) do
    %{errors: ["Unauthorized"]}
  end

  def render("403.json", _assigns) do
    %{errors: ["Forbidden"]}
  end

  def render("404.json", _assigns) do
    %{errors: ["Not Found"]}
  end

  def render("422.json", %{errors: errors}) do
    %{errors: errors}
  end
end
