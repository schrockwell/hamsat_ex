defmodule Hamsat.Schemas.Sat do
  use Hamsat, :schema

  schema "satellites" do
    field :name, :string
    field :number, :integer
    field :slug, :string
    field :tle, :string

    timestamps()
  end

  def upsert_changeset(sat \\ %__MODULE__{}, attrs) do
    sat
    |> cast(attrs, [:name, :number, :slug, :tle])
    |> validate_required([:name, :number, :slug])
  end

  def get_satrec(%__MODULE__{number: number}) do
    Satellite.SatelliteDatabase.lookup(number)
  end
end
