defmodule Hamsat.Schemas.Alert do
  use Hamsat, :schema

  import Hamsat.Changeset

  alias Hamsat.Schemas.Sat
  alias Hamsat.Accounts.User

  schema "alerts" do
    belongs_to :sat, Sat, foreign_key: :satellite_id
    belongs_to :user, User

    field :aos_at, :utc_datetime
    field :los_at, :utc_datetime
    field :callsign, :string
    field :comment, :string
    field :downlink_mhz, :float
    field :mode, :string

    field :is_visible?, :boolean, default: false, virtual: true

    timestamps()
  end

  def insert_changeset(context, pass, attrs \\ %{}) do
    %__MODULE__{
      aos_at: Hamsat.Util.erl_to_utc_datetime(pass.info.aos.datetime),
      los_at: Hamsat.Util.erl_to_utc_datetime(pass.info.los.datetime),
      callsign: context.user.latest_callsign,
      mode: hd(mode_options(pass.sat))
    }
    |> cast(attrs, [
      :callsign,
      :downlink_mhz,
      :mode,
      :comment
    ])
    |> format_callsign()
    |> put_assoc(:user, context.user)
    |> put_assoc(:sat, pass.sat)
    |> validate_required([
      :callsign,
      :aos_at,
      :los_at
    ])
  end

  def mode_options(%Sat{modulation: :fm}), do: ["FM"]
  def mode_options(%Sat{modulation: :linear}), do: ["SSB", "CW", "Data"]
end
