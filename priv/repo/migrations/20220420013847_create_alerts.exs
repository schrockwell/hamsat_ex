defmodule Hamsat.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :satellite_id, references(:satellites, on_delete: :nothing, type: :binary_id)

      add :callsign, :string, null: false
      add :aos_at, :utc_datetime, null: false
      add :los_at, :utc_datetime, null: false
      add :downlink_mhz, :float
      add :mode, :string
      add :comment, :text

      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:satellite_id])
    create index(:alerts, [:aos_at])
  end
end
