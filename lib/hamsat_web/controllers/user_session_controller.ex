defmodule HamsatWeb.UserSessionController do
  use HamsatWeb, :controller

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User
  alias HamsatWeb.UserAuth

  plug :set_page_title

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"token" => token}) do
    with {:ok, user_email} <- UserAuth.verify_sign_in_token(token),
         user = %User{} <- Accounts.get_user_by_email(user_email) do
      conn
      |> put_flash(:info, "Welcome! You are now registered and logged in.")
      |> UserAuth.log_in_user(user)
    else
      _ ->
        conn
        |> put_flash(:error, "There was a problem signing in. Please try again.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp set_page_title(conn, _) do
    assign(conn, :page_title, "Log In")
  end
end
