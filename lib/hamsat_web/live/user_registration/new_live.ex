defmodule HamsatWeb.UserRegistration.NewLive do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  alias HamsatWeb.LocationPicker
  alias HamsatWeb.UserAuth

  def mount(_, _, socket) do
    socket =
      socket
      |> assign(:page_title, "Register")
      |> assign(:sign_in_token, nil)
      |> assign_changeset(%{})

    {:ok, socket}
  end

  def handle_event("form-changed", %{"user" => user_params}, socket) do
    {:noreply, assign_changeset(socket, user_params)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    user_params
    |> Accounts.register_user()
    |> case do
      {:ok, user} ->
        socket =
          socket
          |> assign(:sign_in_token, UserAuth.generate_sign_in_token(user))
          |> push_event("sumbit-registration-form", %{})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_info({LocationPicker, :map_clicked, {lat, lon}}, socket) do
    {:noreply, assign_changeset(socket, %{home_lat: lat, home_lon: lon})}
  end

  defp assign_changeset(socket, params) do
    # We need to keep track of the User being built so that the LocationPicker
    # can detect lat/lon changes on every form change, and update its UI accordingly
    if socket.assigns[:user] do
      changeset = Accounts.change_user_registration(socket.assigns.user, params)
      user = Ecto.Changeset.apply_changes(changeset)

      assign(socket, changeset: changeset, user: user)
    else
      initial_attrs =
        if socket.assigns.context.location do
          %{
            home_lat: socket.assigns.context.location.lat,
            home_lon: socket.assigns.context.location.lon
          }
        else
          %{}
        end

      changeset = Accounts.change_user_registration(%User{}, initial_attrs)
      user = Ecto.Changeset.apply_changes(changeset)
      assign(socket, changeset: changeset, user: user)
    end
  end
end
