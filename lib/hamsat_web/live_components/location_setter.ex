defmodule HamsatWeb.LocationSetter do
  use HamsatWeb, :love_component

  alias Hamsat.Coord
  alias HamsatWeb.LocationPicker

  prop :context
  prop :redirect
  prop :show_log_in_link?, default: false

  state :changeset
  state :clicked_coord, initial: nil
  state :form
  state :form_params, initial: %{}

  defmodule Form do
    use Ecto.Schema

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

  def handle_message(:on_map_clicked, _, {lat, lon}, socket) do
    form = Form.from_coord(%Coord{lat: lat, lon: lon})
    changeset = Form.changeset(form)
    put_state(socket, changeset: changeset, form: form)
  end

  def handle_event("form-changed", %{"form" => params}, socket) do
    changeset = Form.changeset(socket.assigns.form, params)
    form = Ecto.Changeset.apply_changes(changeset)

    {:noreply, put_state(socket, changeset: changeset, form: form)}
  end

  @react to: :context
  def put_initial_form(socket) do
    form = Form.from_coord(socket.assigns.context.location)
    changeset = Form.changeset(form)
    put_state(socket, changeset: changeset, form: form)
  end
end
