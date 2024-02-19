defmodule Hamsat.Schemas.Sat do
  use Hamsat, :schema

  alias Hamsat.Schemas.FreqRange
  alias Hamsat.Schemas.Transponder

  schema "satellites" do
    field :name, :string
    field :nasa_name, :string
    field :number, :integer
    field :slug, :string
    field :modulations, {:array, Ecto.Enum}, values: Hamsat.Modulation.sat_values()
    field :aliases, {:array, :string}, default: []

    embeds_many :downlinks, FreqRange, on_replace: :delete
    embeds_many :uplinks, FreqRange, on_replace: :delete

    # Aggregate fields
    field :total_activation_count, :integer, virtual: true

    has_many :transponders, Transponder, foreign_key: :satellite_id, on_replace: :delete

    timestamps()
  end

  def upsert_changeset(sat \\ %__MODULE__{}, attrs) do
    sat
    |> cast(attrs, [:name, :number, :slug, :nasa_name, :modulations, :aliases])
    |> put_nasa_name()
    |> validate_required([:name, :number, :slug, :nasa_name, :modulations])
    |> cast_embed(:downlinks, with: &FreqRange.changeset/2)
    |> cast_embed(:uplinks, with: &FreqRange.changeset/2)
    |> cast_assoc(:transponders, with: &Transponder.changeset/2)
  end

  defp put_nasa_name(changeset) do
    if get_field(changeset, :nasa_name) do
      changeset
    else
      put_change(changeset, :nasa_name, get_field(changeset, :name))
    end
  end

  def get_satrec(%__MODULE__{number: number}) do
    Satellite.SatelliteDatabase.lookup(number)
  end

  def subbands(%__MODULE__{} = sat, direction, modes) do
    field = if direction == :uplinks, do: :uplink, else: :downlink

    filter_modes =
      modes
      |> Enum.flat_map(fn
        :linear -> [:linear, :linear_non_inv]
        mode -> [mode]
      end)

    sat.transponders
    |> Enum.filter(fn t ->
      case filter_modes do
        [] -> true
        _ -> t.mode in filter_modes
      end
    end)
    |> Enum.map(fn t -> Map.fetch!(t, field) end)
  end
end
