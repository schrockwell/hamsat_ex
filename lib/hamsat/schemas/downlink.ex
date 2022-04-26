defmodule Hamsat.Schemas.Downlink do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :lower_mhz, :float
    field :upper_mhz, :float
  end

  def changeset(downlink, attrs \\ %{}) do
    downlink
    |> cast(attrs, [:lower_mhz, :upper_mhz])
    |> validate_required([:lower_mhz, :upper_mhz])
  end
end
