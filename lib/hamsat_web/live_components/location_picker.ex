defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias Hamsat.Grid

  defmodule Form do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :grid, :string
      field :lat, :float
      field :lon, :float
    end

    def changeset(form, params \\ %{}) do
      form
      |> cast(params, [:grid, :lat, :lon])
      |> validate_number(:lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
      |> validate_number(:lon, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
      |> maybe_update_coord_from_grid()
      |> maybe_update_grid_from_coord()
      |> Map.put(:action, :update)
    end

    # When the grid field changes to a valid value, automatically set new coords
    defp maybe_update_coord_from_grid(changeset) do
      with {:ok, new_grid} <- fetch_change(changeset, :grid),
           {:ok, {lat, lon}} <- Grid.decode(new_grid) do
        change(changeset, lat: lat, lon: lon)
      else
        _ -> changeset
      end
    end

    # When the coord fields change, automatically set a new grid
    defp maybe_update_grid_from_coord(changeset) do
      new_lat = get_field(changeset, :lat, 0)
      new_lon = get_field(changeset, :lon, 0)

      case Grid.encode(new_lat, new_lon, 6) do
        {:ok, new_grid} -> change(changeset, grid: new_grid)
        :error -> changeset
      end
    end

    def to_coord(form) do
      if is_float(form.lat) and is_float(form.lon) do
        %Coord{lat: form.lat, lon: form.lon}
      end
    end
  end

  def mount(socket) do
    socket =
      socket
      |> assign(:mapbox_access_token, Application.fetch_env!(:hamsat, :mapbox_access_token))
      |> assign(:form, %Form{})
      |> try_updating_coord(%{}, event?: false)

    {:ok, socket}
  end

  def update(assigns, socket) do
    previous_coord = socket.assigns[:coord]

    socket =
      socket
      |> assign(assigns)
      |> update_coord_if_changed(previous_coord)

    {:ok, socket}
  end

  defp update_coord_if_changed(socket, previous_coord) do
    current_coord = socket.assigns[:coord]

    cond do
      current_coord == previous_coord ->
        socket

      current_coord == nil ->
        clear_coord(socket, event?: false)

      true ->
        try_updating_coord(socket, %{lat: current_coord.lat, lon: current_coord.lon},
          event?: false
        )
    end
  end

  def handle_event("form-changed", %{"form" => params}, socket) do
    socket = try_updating_coord(socket, params)
    {:noreply, socket}
  end

  def handle_event("map-clicked", %{"lat" => _lat, "lon" => _lon} = params, socket) do
    socket = try_updating_coord(socket, params)
    {:noreply, socket}
  end

  defp push_marker_coord(socket, coord) do
    coord_payload =
      case coord do
        nil -> nil
        %Coord{lat: lat, lon: lon} -> %{"lat" => lat, "lon" => lon}
      end

    socket |> push_event("set-marker", %{"id" => "location-picker-map", "coord" => coord_payload})
  end

  defp clear_coord(socket, opts) do
    event? = Keyword.get(opts, :event?, true)

    form = %Form{}
    changeset = Form.changeset(form)

    if event? do
      emit_coord_selected(socket, nil)
    end

    socket
    |> assign(changeset: changeset, form: form, coord: nil)
    |> push_marker_coord(nil)
  end

  defp try_updating_coord(socket, params, opts \\ []) do
    event? = Keyword.get(opts, :event?, true)

    changeset = Form.changeset(socket.assigns.form, params)

    if changeset.valid? do
      form = Ecto.Changeset.apply_changes(changeset)
      coord = Form.to_coord(form)

      if event? do
        emit_coord_selected(socket, coord)
      end

      socket
      |> assign(changeset: changeset, form: form, coord: coord)
      |> push_marker_coord(coord)
    else
      assign(socket, changeset: changeset)
    end
  end

  defp emit_coord_selected(socket, coord) do
    case socket.assigns[:target] do
      nil -> send(self(), {__MODULE__, :coord_selected, coord})
      {module, id} -> send_update(module, id: id, __location_picker_coord_selected__: coord)
    end

    socket
  end
end
