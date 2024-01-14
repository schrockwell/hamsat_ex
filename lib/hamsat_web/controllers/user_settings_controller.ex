defmodule HamsatWeb.UserSettingsController do
  use HamsatWeb, :controller

  alias Hamsat.Accounts
  alias HamsatWeb.UserAuth

  plug :assign_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_match_preferences", "user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_match_preferences(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Preferences updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> render("edit.html", match_preferences_changeset: Accounts.change_user_match_preferences(user))

      {:error, changeset} ->
        render(conn, "edit.html", match_preferences_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_callsign", "user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_callsign(user, user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Callsign changed successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> render("edit.html", callsign_changeset: Accounts.change_user_callsign(user))

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Could not change callsign, please see below.")
        |> render("edit.html", callsign_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_changesets(conn, _opts) do
    user = conn.assigns.current_user

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
    |> assign(:match_preferences_changeset, Accounts.change_user_match_preferences(user))
    |> assign(:callsign_changeset, Accounts.change_user_callsign(user))
  end
end
