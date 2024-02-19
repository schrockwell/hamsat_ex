defmodule Hamsat.Schemas.FreqRange do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :lower_mhz, :float
    field :upper_mhz, :float
    field :mode, Ecto.Enum, values: Hamsat.Modulation.sat_values()
  end

  def changeset(freq_range, attrs \\ %{}) do
    freq_range
    |> cast(attrs, [:lower_mhz, :upper_mhz, :mode])
    |> validate_required([:lower_mhz, :upper_mhz])
  end
end
