defmodule Hamsat.Schemas.Sat do
  use Hamsat, :schema

  alias Hamsat.Schemas.FreqRange

  schema "satellites" do
    field :name, :string
    field :nasa_name, :string
    field :number, :integer
    field :slug, :string
    field :modulations, {:array, Ecto.Enum}, values: Hamsat.Modulation.sat_values()

    embeds_many :downlinks, FreqRange, on_replace: :delete
    embeds_many :uplinks, FreqRange, on_replace: :delete

    timestamps()
  end

  def upsert_changeset(sat \\ %__MODULE__{}, attrs) do
    sat
    |> cast(attrs, [:name, :number, :slug, :nasa_name, :modulations])
    |> put_nasa_name()
    |> validate_required([:name, :number, :slug, :nasa_name, :modulations])
    |> cast_embed(:downlinks, with: &FreqRange.changeset/2)
    |> cast_embed(:uplinks, with: &FreqRange.changeset/2)
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
end
