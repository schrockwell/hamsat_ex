defmodule Hamsat.Schemas.Transponder do
  use Hamsat, :schema

  alias Hamsat.Schemas.FreqRange
  alias Hamsat.Schemas.Sat

  schema "transponders" do
    belongs_to :sat, Sat, foreign_key: :satellite_id

    embeds_one :downlink, FreqRange, on_replace: :delete
    embeds_one :uplink, FreqRange, on_replace: :delete

    field :status, Ecto.Enum, values: [:active, :problems, :inactive, :unknown]
    field :mode, Ecto.Enum, values: [:linear, :linear_non_inv, :fm, :digital, :cw_beacon, :telemetry]
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(transponder, attrs) do
    transponder
    |> cast(attrs, [
      :status,
      :mode,
      :notes
    ])
    |> cast_embed(:downlink, with: &FreqRange.changeset/2)
    |> cast_embed(:uplink, with: &FreqRange.changeset/2)
    |> validate_required([:mode, :status])
  end
end
