defmodule HamsatWeb.LocationSetter do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias HamsatWeb.LocationPicker

  prop :context
  prop :redirect
  prop :show_log_in_link?, default: false

  state :changeset
  state :clicked_coord, initial: nil
  state :form
  state :changes, initial: %{}

  defmodule Form do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :grid, :string
      field :lat, :float
      field :lon, :float
      field :timezone, :string, default: "Etc/UTC"
    end

    def changeset(form, params \\ %{}, opts \\ []) do
      Hamsat.Util.location_picker_changeset(form, params, opts)
    end

    def from_context(context) do
      coord = context.location || %Coord{lat: 0.0, lon: 0.0}
      %__MODULE__{lat: coord.lat, lon: coord.lon, timezone: context.timezone}
    end
  end

  def handle_emit(:on_map_clicked, _, {lat, lon}, socket) do
    changes = %{lat: lat, lon: lon}
    changeset = Form.changeset(socket.assigns.changeset, changes)

    {:ok, put_state(socket, changeset: changeset)}
  end

  def handle_event("form-changed", %{"_target" => target, "form" => params}, socket) do
    # When the user touches the grid input, recalculate the coordinate fields
    opts = if target == ["form", "grid"], do: [update: :coord], else: []

    changeset = Form.changeset(socket.assigns.changeset, params, opts)

    {:noreply, put_state(socket, changeset: changeset)}
  end

  @react to: :context
  def put_initial_changeset(socket) do
    changeset =
      socket.assigns.context
      |> Form.from_context()
      |> Form.changeset()

    put_state(socket, changeset: changeset)
  end
end
