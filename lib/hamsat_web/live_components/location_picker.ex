defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :live_component

  @default_field_mapping %{lat: :lat, lon: :lon, grid: :grid}

  prop :fields, default: @default_field_mapping
  prop :form
  prop :mapbox_access_token, default: Application.fetch_env!(:hamsat, :mapbox_access_token)
  prop :show_grid?, default: true

  event :on_map_clicked

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> compute_field_keys()
     |> push_marker_coord()}
  end

  def compute_field_keys(socket) do
    if changed?(socket, :fields) do
      assign(socket, field_keys: Map.merge(@default_field_mapping, socket.assigns.fields))
    else
      socket
    end
  end

  def push_marker_coord(socket) do
    if changed?(socket, :form) do
      socket
      |> push_event("set-marker", %{
        "id" => "location-picker-map",
        "coord" => %{
          "lat" => Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lat),
          "lon" => Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lon)
        }
      })
    else
      socket
    end
  end

  def handle_event("map-clicked", %{"lat" => lat, "lon" => lon}, socket) do
    {:noreply, emit(socket, :on_map_clicked, {lat, lon})}
  end
end
