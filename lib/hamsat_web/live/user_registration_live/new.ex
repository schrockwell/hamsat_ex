defmodule HamsatWeb.UserRegistrationLive.New do
  use HamsatWeb, :live_view

  alias Hamsat.Accounts
  alias Hamsat.Accounts.User

  alias HamsatWeb.LocationPicker
  alias HamsatWeb.UserAuth

  state :changeset
  state :page_title, default: "Register"
  state :sign_in_token, default: nil

  def mount(_, _, %{assigns: %{context: context}} = socket) do
    initial_attrs =
      if context.location do
        %{
          home_lat: context.location.lat,
          home_lon: context.location.lon,
          timezone: context.timezone
        }
      else
        %{
          home_lat: 0.0,
          home_lon: 0.0,
          timezone: "Etc/UTC"
        }
      end

    changeset = Accounts.change_user_registration(%User{}, initial_attrs)
    socket = put_state(socket, changeset: changeset)

    {:ok, socket}
  end

  def handle_event("form-changed", %{"_target" => target, "user" => user_params}, socket) do
    # When the user touches the grid input, recalculate the coordinate fields
    opts = if target == ["user", "home_grid"], do: [update: :coord], else: []

    changeset = Accounts.change_user_registration(socket.assigns.changeset, user_params, opts)

    {:noreply, put_state(socket, changeset: changeset)}
  end

  def handle_event("submit", %{"user" => user_params}, socket) do
    user_params
    |> Accounts.register_user()
    |> case do
      {:ok, user} ->
        socket =
          socket
          |> put_state(sign_in_token: UserAuth.generate_sign_in_token(user))
          |> push_event("sumbit-registration-form", %{})

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_state(socket, changeset: changeset)}
    end
  end

  def handle_emit(:on_map_clicked, _, {lat, lon}, socket) do
    changes = %{home_lat: lat, home_lon: lon}
    changeset = Accounts.change_user_registration(socket.assigns.changeset, changes)
    {:ok, put_state(socket, changeset: changeset)}
  end
end
