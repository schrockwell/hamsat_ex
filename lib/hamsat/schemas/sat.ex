defmodule Hamsat.Schemas.Sat do
  use Hamsat, :schema

  alias Hamsat.Schemas.Downlink

  schema "satellites" do
    field :name, :string
    field :number, :integer
    field :slug, :string
    field :modulation, Ecto.Enum, values: [:fm, :linear]

    embeds_many :downlinks, Downlink

    timestamps()
  end

  def upsert_changeset(sat \\ %__MODULE__{}, attrs) do
    sat
    |> cast(attrs, [:name, :number, :slug, :modulation])
    |> validate_required([:name, :number, :slug, :modulation])
    |> cast_embed(:downlinks, with: &Downlink.changeset/2)
  end

  def get_satrec(%__MODULE__{number: number}) do
    Satellite.SatelliteDatabase.lookup(number)
  end
end
