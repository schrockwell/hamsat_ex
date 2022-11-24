defmodule Hamsat.Schemas.Alert do
  use Hamsat, :schema

  import Hamsat.Changeset

  alias Hamsat.Accounts.User
  alias Hamsat.Modulation
  alias Hamsat.Schemas.Sat
  alias Hamsat.Schemas.SavedAlert

  schema "alerts" do
    belongs_to :sat, Sat, foreign_key: :satellite_id
    belongs_to :user, User
    has_many :saved_alerts, SavedAlert

    field :aos_at, :utc_datetime
    field :max_at, :utc_datetime
    field :los_at, :utc_datetime
    field :callsign, :string
    field :comment, :string
    field :downlink_mhz, :float
    field :mode, :string
    field :observer_lat, :float
    field :observer_lon, :float

    field :is_workable?, :boolean, default: false, virtual: true
    field :workable_start_at, :utc_datetime, virtual: true
    field :workable_end_at, :utc_datetime, virtual: true
    field :my_closest_position, :map, default: nil, virtual: true
    field :activator_closest_position, :map, default: nil, virtual: true

    field :saved_count, :integer, default: nil, virtual: true
    field :saved?, :boolean, default: false, virtual: true

    field :match, :map, default: nil, virtual: true

    timestamps()
  end

  def observer_coord(alert) do
    %Hamsat.Coord{lat: alert.observer_lat, lon: alert.observer_lon}
  end

  def insert_changeset(context, pass, attrs \\ %{}) do
    %__MODULE__{}
    |> change(%{
      aos_at: Hamsat.Util.erl_to_utc_datetime(pass.info.aos.datetime),
      max_at: Hamsat.Util.erl_to_utc_datetime(pass.info.max.datetime),
      los_at: Hamsat.Util.erl_to_utc_datetime(pass.info.los.datetime),
      callsign: context.user.latest_callsign,
      mode: preferred_mode(context.user, pass.sat),
      downlink_mhz: preferred_downlink_mhz(pass.sat),
      observer_lat: context.location.lat,
      observer_lon: context.location.lon
    })
    |> put_assoc(:user, context.user)
    |> put_assoc(:sat, pass.sat)
    |> update_changeset(attrs)
  end

  def update_changeset(alert, attrs \\ %{}) do
    alert
    |> cast(attrs, [
      :callsign,
      :downlink_mhz,
      :mode,
      :comment
    ])
    |> format_callsign()
    |> validate_required([:callsign])
    |> validate_length(:callsign, min: 3)
    |> validate_length(:comment, max: 50)
  end

  defp preferred_mode(user, sat) do
    case Modulation.alert_options(sat) do
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

  defp preferred_downlink_mhz(%Sat{downlinks: [%{lower_mhz: mhz, upper_mhz: mhz}]}), do: mhz
  defp preferred_downlink_mhz(_sat), do: nil

  def progression(alert, now) do
    cond do
      Timex.compare(now, alert.aos_at) == -1 -> :upcoming
      Timex.compare(now, alert.los_at) == 1 -> :passed
      alert.is_workable? and Timex.compare(now, alert.workable_start_at) == -1 -> :before_workable
      alert.is_workable? and Timex.compare(now, alert.workable_end_at) == 1 -> :after_workable
      alert.is_workable? -> :workable
      true -> :in_progress
    end
  end

  def events(alert, now) do
    upcoming_event =
      {:upcoming,
       %{
         event: :upcoming,
         start_at: min_datetime(now, alert.aos_at),
         end_at: alert.aos_at
       }}

    passed_event =
      {:passed,
       %{
         event: :passed,
         start_at: alert.los_at,
         end_at: alert.los_at
       }}

    before_workable_event =
      if alert.is_workable? and alert.workable_start_at != alert.aos_at do
        {:before_workable,
         %{
           event: :before_workable,
           start_at: alert.aos_at,
           end_at: alert.workable_start_at
         }}
      end

    workable_event =
      if alert.is_workable? do
        {:workable,
         %{
           event: :workable,
           start_at: alert.workable_start_at,
           end_at: alert.workable_end_at
         }}
      end

    after_workable_event =
      if alert.is_workable? and alert.workable_end_at != alert.los_at do
        {:after_workable,
         %{
           event: :after_workable,
           start_at: alert.workable_end_at,
           end_at: alert.los_at
         }}
      end

    in_progress_event =
      if not alert.is_workable? do
        {:in_progress,
         %{
           event: :in_progress,
           start_at: alert.aos_at,
           end_at: alert.los_at
         }}
      end

    [
      upcoming_event,
      in_progress_event,
      before_workable_event,
      workable_event,
      after_workable_event,
      passed_event
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp min_datetime(d1, d2) do
    if DateTime.compare(d1, d2) == :lt, do: d1, else: d2
  end

  defp seconds_until(now, then) do
    Timex.diff(then, now, :second)
  end

  def next_event(%__MODULE__{} = alert, now) do
    cond do
      alert.is_workable? and Timex.compare(now, alert.workable_start_at) < 1 ->
        {:workable, :start, seconds_until(now, alert.workable_start_at)}

      alert.is_workable? and Timex.compare(now, alert.workable_end_at) < 1 ->
        {:workable, :end, seconds_until(now, alert.workable_end_at)}

      not alert.is_workable? and Timex.compare(now, alert.aos_at) < 1 ->
        {:unworkable, :start, seconds_until(now, alert.aos_at)}

      not alert.is_workable? and Timex.compare(now, alert.los_at) < 1 ->
        {:unworkable, :end, seconds_until(now, alert.los_at)}

      true ->
        :never
    end
  end

  def owned?(_alert, :guest), do: false
  def owned?(%__MODULE__{} = alert, %User{} = user), do: alert.user_id == user.id
end
