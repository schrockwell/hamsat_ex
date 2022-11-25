defmodule Hamsat.Schemas.FreqRange do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :lower_mhz, :float
    field :upper_mhz, :float
  end

  def changeset(freq_range, attrs \\ %{}) do
    freq_range
    |> cast(attrs, [:lower_mhz, :upper_mhz])
    |> validate_required([:lower_mhz, :upper_mhz])
  end
end
