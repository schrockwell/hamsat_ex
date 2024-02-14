defmodule HamsatWeb.LocationPicker do
  use HamsatWeb, :live_component

  @default_field_mapping %{lat: :lat, lon: :lon, grid: :grid}

  attr :fields, :map, default: @default_field_mapping
  attr :form, :map, required: true
  attr :id, :string, required: true
  attr :on_map_clicked, :any, required: true
  attr :show_grid?, :boolean, default: true

  def component(assigns) do
    ~H"""
    <.live_component
      module={__MODULE__}
      fields={@fields}
      form={@form}
      id={@id}
      on_map_clicked={@on_map_clicked}
      show_grid?={@show_grid?}
    />
    """
  end

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
