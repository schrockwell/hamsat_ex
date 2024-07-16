defmodule Hamsat.Schemas.Alert do
  use Hamsat, :schema

  alias Hamsat.Accounts.User
  alias Hamsat.Schemas.AlertForm
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
    field :mhz, :float
    field :mhz_direction, Ecto.Enum, values: [:up, :down]
    field :mode, :string
    field :observer_lat, :float
    field :observer_lon, :float
    field :grids, {:array, :string}

    field :is_workable?, :boolean, default: false, virtual: true
    field :workable_start_at, :utc_datetime, virtual: true
    field :workable_end_at, :utc_datetime, virtual: true
    field :my_closest_position, :map, default: nil, virtual: true
    field :activator_closest_position, :map, default: nil, virtual: true
    field :max_elevation, :float, default: nil, virtual: true

    field :saved_count, :integer, default: nil, virtual: true
    field :saved?, :boolean, default: false, virtual: true

    field :match, :map, default: nil, virtual: true

    timestamps()
  end

  def observer_coord(alert) do
    %Hamsat.Coord{lat: alert.observer_lat, lon: alert.observer_lon}
  end

  def changeset(%__MODULE__{} = alert, %AlertForm{} = alert_form) do
    alert
    |> change(%{
      aos_at: Hamsat.Util.erl_to_utc_datetime(alert_form.pass.info.aos.datetime),
      max_at: Hamsat.Util.erl_to_utc_datetime(alert_form.pass.info.max.datetime),
      los_at: Hamsat.Util.erl_to_utc_datetime(alert_form.pass.info.los.datetime),
      callsign: alert_form.callsign,
      mode: alert_form.mode,
      mhz: alert_form.mhz,
      mhz_direction: alert_form.mhz_direction,
      observer_lat: alert_form.observer_lat,
      observer_lon: alert_form.observer_lon,
      satellite_id: alert_form.satellite_id,
      user_id: alert_form.context.user.id,
      comment: alert_form.comment,
      grids: grids_from_alert_form(alert_form)
    })
    |> validate_required([
      :callsign,
      :aos_at,
      :max_at,
      :los_at,
      :observer_lat,
      :observer_lon,
      :mhz_direction,
      :grids
    ])
  end

  defp grids_from_alert_form(alert_form) do
    [:grid_1, :grid_2, :grid_3, :grid_4] |> Enum.map(&Map.get(alert_form, &1)) |> Enum.reject(&is_nil/1)
  end

  def progression(alert, now) do
    cond do
      Timex.compare(now, alert.aos_at) == -1 -> :upcoming
      Timex.compare(now, alert.los_at) == 1 -> :passed
      alert.is_workable? && Timex.compare(now, alert.workable_start_at) == -1 -> :before_workable
      alert.is_workable? && Timex.compare(now, alert.workable_end_at) == 1 -> :after_workable
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
      if alert.is_workable? && alert.workable_start_at != alert.aos_at do
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
      if alert.is_workable? && alert.workable_end_at != alert.los_at do
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
      alert.is_workable? && Timex.compare(now, alert.workable_start_at) < 1 ->
        {:workable, :start, seconds_until(now, alert.workable_start_at)}

      alert.is_workable? && Timex.compare(now, alert.workable_end_at) < 1 ->
        {:workable, :end, seconds_until(now, alert.workable_end_at)}

      !alert.is_workable? && Timex.compare(now, alert.aos_at) < 1 ->
        {:unworkable, :start, seconds_until(now, alert.aos_at)}

      !alert.is_workable? && Timex.compare(now, alert.los_at) < 1 ->
        {:unworkable, :end, seconds_until(now, alert.los_at)}

      true ->
        :never
    end
  end

  def owned?(_alert, :guest), do: false
  def owned?(%__MODULE__{} = alert, %User{} = user), do: alert.user_id == user.id
end
