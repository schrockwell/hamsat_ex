defmodule Hamsat.Schemas.Alert do
  use Hamsat, :schema

  schema "alerts" do
    belongs_to :sat, Hamsat.Schemas.Sat, foreign_key: :satellite_id

    field :aos_at, :utc_datetime
    field :callsign, :string
    field :comment, :string
    field :downlink_mhz, :float
    field :los_at, :utc_datetime
    field :mode, :string

    timestamps()
  end

  def insert_changeset(_context, pass, attrs \\ %{}) do
    %__MODULE__{
      aos_at: Hamsat.Util.erl_to_utc_datetime(pass.aos.datetime),
      los_at: Hamsat.Util.erl_to_utc_datetime(pass.los.datetime)
    }
    |> cast(attrs, [
      :callsign,
      :downlink_mhz,
      :mode,
      :comment
    ])
    |> put_assoc(:sat, pass.sat)
    |> validate_required([
      :callsign,
      :aos_at,
      :los_at
    ])
  end
end
