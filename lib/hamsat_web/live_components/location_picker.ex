defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :love_component

  @default_field_mapping %{lat: :lat, lon: :lon, grid: :grid}

  prop :fields, default: @default_field_mapping
  prop :form
  prop :id
  prop :mapbox_access_token, default: Application.compile_env!(:hamsat, :mapbox_access_token)
  prop :target

  computed :field_keys

  @react to: :fields
  def compute_field_keys(socket) do
    put_computed(socket, :field_keys, Map.merge(@default_field_mapping, socket.assigns.fields))
  end

  @react to: :form
  def push_marker_coord(socket) do
    socket
    |> push_event("set-marker", %{
      "id" => "location-picker-map",
      "coord" => %{
        "lat" => Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lat),
        "lon" => Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lon)
      }
    })
  end

  def handle_event("map-clicked", %{"lat" => lat, "lon" => lon}, socket) do
    case socket.assigns.target do
      :self -> send(self(), {__MODULE__, :map_clicked, {lat, lon}})
      {module, id} -> send_update(module, id: id, __map_clicked__: {lat, lon})
      nil -> nil
    end

    {:noreply, socket}
  end
end
