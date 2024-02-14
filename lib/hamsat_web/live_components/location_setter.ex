defmodule HamsatWeb.LocationSetter do
  use HamsatWeb, :live_component

  alias Hamsat.Coord
  alias HamsatWeb.LocationPicker

  attr :context, Hamsat.Context, required: true
  attr :id, :string, required: true
  attr :redirect, :string, required: true
  attr :show_log_in_link?, :boolean, default: false

  def component(assigns) do
    ~H"""
    <.live_component
      module={__MODULE__}
      context={@context}
      id={@id}
      redirect={@redirect}
      show_log_in_link?={@show_log_in_link?}
    />
    """
  end

  defmodule Form do
    use Ecto.Schema

    @primary_key false
    embedded_schema do
      field :grid, :string
      field :lat, :float
      field :lon, :float
      field :timezone, :string, default: "Etc/UTC"
      field :time_format, :string, default: "24h"
    end

    def changeset(form, params \\ %{}, opts \\ []) do
      Hamsat.Util.location_picker_changeset(form, params, opts)
    end

    def from_context(context) do
      coord = context.location || %Coord{lat: 0.0, lon: 0.0}
      %__MODULE__{lat: coord.lat, lon: coord.lon, timezone: context.timezone, time_format: context.time_format}
    end
  end

  def mount(socket) do
    {:ok, assign(socket, clicked_coord: nil, changes: %{})}
  end

  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> put_initial_changeset()}
  end

  def handle_emit(:on_map_clicked, _, {lat, lon}, socket) do
    changes = %{lat: lat, lon: lon}
    changeset = Form.changeset(socket.assigns.changeset, changes)

    {:ok, assign(socket, changeset: changeset)}
  end

  def handle_event("form-changed", %{"_target" => target, "form" => params}, socket) do
    # When the user touches the grid input, recalculate the coordinate fields
    opts = if target == ["form", "grid"], do: [update: :coord], else: []

    changeset = Form.changeset(socket.assigns.changeset, params, opts)

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp put_initial_changeset(socket) do
    if changed?(socket, :context) do
      changeset =
        socket.assigns.context
        |> Form.from_context()
        |> Form.changeset()

      assign(socket, changeset: changeset)
    else
      socket
    end
  end
end
