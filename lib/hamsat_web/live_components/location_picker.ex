defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :live_component

  @default_field_mapping %{lat: :lat, lon: :lon, grid: :grid}

  def mount(socket) do
    socket =
      socket
      |> assign(:mapbox_access_token, Application.fetch_env!(:hamsat, :mapbox_access_token))
      |> assign(:fields, @default_field_mapping)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_field_names()
      |> push_marker_coord()

    {:ok, socket}
  end

  def handle_event("map-clicked", %{"lat" => lat, "lon" => lon} = params, socket) do
    case socket.assigns[:target] do
      :self -> send(self(), {__MODULE__, :map_clicked, {lat, lon}})
      {module, id} -> send_update(module, id: id, __map_clicked__: {lat, lon})
      nil -> nil
    end

    {:noreply, socket}
  end

  defp push_marker_coord(socket) do
    if changed?(socket, :form) and connected?(socket) do
      socket
      |> push_event("set-marker", %{
        "id" => "location-picker-map",
        "coord" => %{
          "lat" =>
            Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lat),
          "lon" => Ecto.Changeset.get_field(socket.assigns.form.source, socket.assigns.fields.lon)
        }
      })
    else
      socket
    end
  end

  defp assign_field_names(socket) do
    if changed?(socket, :fields) do
      assign(socket, :fields, Map.merge(@default_field_mapping, socket.assigns.fields))
    else
      socket
    end
  end
end
