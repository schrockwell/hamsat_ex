defmodule HamsatWeb.LocationSetter do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias HamsatWeb.LocationPicker

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
      Hamsat.Util.location_picker_changeset(form, params)
    end

    def from_coord(nil) do
      changeset(%__MODULE__{})
    end

    def from_coord(coord) do
      %__MODULE__{lat: coord.lat, lon: coord.lon}
    end
  end

  def mount(socket) do
    {:ok, assign(socket, :show_log_in_link?, false)}
  end

  def update(%{__map_clicked__: {lat, lon}}, socket) do
    form = Form.from_coord(%Coord{lat: lat, lon: lon})
    changeset = Form.changeset(form)
    {:ok, assign(socket, changeset: changeset, form: form)}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> extract_context_coord()}
  end

  defp extract_context_coord(socket) do
    if changed?(socket, :context) do
      form = Form.from_coord(socket.assigns.context.location)
      changeset = Form.changeset(form)
      assign(socket, changeset: changeset, form: form)
    else
      socket
    end
  end

  def handle_event("form-changed", %{"form" => params}, socket) do
    changeset = Form.changeset(socket.assigns.form, params)
    form = Ecto.Changeset.apply_changes(changeset)
    {:noreply, assign(socket, changeset: changeset, form: form)}
  end
end
