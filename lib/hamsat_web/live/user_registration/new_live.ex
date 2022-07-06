defmodule HamsatWeb.UserRegistration.NewLive do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User
  alias Hamsat.Coord

  alias HamsatWeb.LocationPicker

  def mount(_, _, socket) do
    socket =
      socket
      |> assign(:changeset, Accounts.change_user_registration(%User{}))
      |> assign(:coord, socket.assigns.context.location || %Coord{lat: 0, lon: 0})

    {:ok, socket}
  end

  def handle_event("form-changed", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    user_params
    |> merge_home_coord_params(socket.assigns.coord)
    |> Accounts.register_user()
    |> case do
      {:ok, _user} ->
        # {:ok, _} =
        #   Accounts.deliver_user_confirmation_instructions(
        #     user,
        #     &Routes.user_confirmation_url(socket, :edit, &1)
        #   )

        socket =
          socket
          |> put_flash(:info, "Registered! Please sign in.")
          |> redirect(to: Routes.user_session_path(socket, :new))

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp merge_home_coord_params(user_params, coord) do
    Map.merge(user_params, %{"home_lat" => coord.lat, "home_lon" => coord.lon})
  end

  def handle_info({LocationPicker, :coord_selected, coord}, socket) do
    {:noreply, assign(socket, :coord, coord)}
  end
end
