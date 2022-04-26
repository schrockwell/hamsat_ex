defmodule Hamsat.Schemas.Alert do
  use Hamsat, :schema

  import Hamsat.Changeset

  alias Hamsat.Schemas.Sat
  alias Hamsat.Accounts.User

  schema "alerts" do
    belongs_to :sat, Sat, foreign_key: :satellite_id
    belongs_to :user, User

    field :aos_at, :utc_datetime
    field :max_at, :utc_datetime
    field :los_at, :utc_datetime
    field :callsign, :string
    field :comment, :string
    field :downlink_mhz, :float
    field :mode, :string
    field :observer_lat, :float
    field :observer_lon, :float

    field :is_visible?, :boolean, default: false, virtual: true

    timestamps()
  end

  def insert_changeset(context, pass, attrs \\ %{}) do
    %__MODULE__{}
    |> change(%{
      aos_at: Hamsat.Util.erl_to_utc_datetime(pass.info.aos.datetime),
      max_at: Hamsat.Util.erl_to_utc_datetime(pass.info.max.datetime),
      los_at: Hamsat.Util.erl_to_utc_datetime(pass.info.los.datetime),
      callsign: context.user.latest_callsign,
      mode: preferred_mode(context.user, pass.sat),
      observer_lat: context.location.lat,
      observer_lon: context.location.lon
    })
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
    |> validate_length(:callsign, min: 3)
  end

  def mode_options(%Sat{modulation: :fm}), do: ["FM"]
  def mode_options(%Sat{modulation: :linear}), do: ["SSB", "CW", "Data"]

  defp preferred_mode(user, sat) do
    case mode_options(sat) do
      [mode] ->
        mode

      sat_modes ->
        # The list of latest_modes is ordered by most-recent, so try to find the first one
        # that is applicable to this satellite
        Enum.find(user.latest_modes, hd(sat_modes), fn mode ->
          mode in sat_modes
        end)
    end
  end
end
