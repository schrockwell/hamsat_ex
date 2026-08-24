defmodule HamsatWeb.UserRegistrationTest do
  use HamsatWeb.ConnCase

  import Phoenix.LiveViewTest
  import Hamsat.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/users/register")

      assert html =~ "Register"
      assert html =~ "Email"
      assert html =~ "Password"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == "/"
    end
  end

  describe "registration form" do
    test "creates an account with valid data", %{conn: conn} do
      email = unique_user_email()
      {:ok, view, _html} = live(conn, ~p"/users/register")

      view
      |> element("form[phx-submit=submit]")
      |> render_submit(%{"user" => valid_user_attributes(email: email)})

      assert Hamsat.Accounts.get_user_by_email(email)
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/register")

      html =
        view
        |> element("form[phx-submit=submit]")
        |> render_submit(%{"user" => %{"email" => "with spaces", "password" => "short"}})

      assert html =~ "must have the @ sign and no spaces"
      assert html =~ "should be at least 8 character"
    end
  end
end
