defmodule Hamsat.Repo.Migrations.CreateTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false, collate: :nocase
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      add :home_lat, :float, null: false
      add :home_lon, :float, null: false
      add :latest_callsign, :string
      add :latest_modes, :string, null: false, default: "[]"
      add :latest_mhz_direction, :string, null: false, default: "down"
      add :prefer_cw_mode, :integer, null: false, default: 50
      add :prefer_ssb_mode, :integer, null: false, default: 50
      add :prefer_data_mode, :integer, null: false, default: 50
      add :prefer_fm_mode, :integer, null: false, default: 50
      add :prefer_dx_el, :integer, null: false, default: 45
      add :prefer_my_el, :integer, null: false, default: 45
      add :timezone, :string, null: false, default: "Etc/UTC"
      add :time_format, :string, default: "24h"
      add :feed_key, :string
      add :callsign, :string

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:callsign])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    create table(:satellites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :number, :integer, null: false
      add :name, :text, null: false
      add :slug, :text, null: false
      add :nasa_name, :string, null: false
      add :modulations, :string, null: false, default: "[]"
      add :aliases, :string, null: false, default: "[]"
      add :in_orbit, :boolean, null: false, default: false
      add :is_active, :boolean, null: false, default: false
      add :tle, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:satellites, [:number])
    create unique_index(:satellites, [:slug])
    create unique_index(:satellites, [:name])
    create index(:satellites, [:in_orbit])
    create index(:satellites, [:is_active])

    create table(:transponders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :satellite_id, references(:satellites, type: :binary_id, on_delete: :delete_all)
      add :uplink, :map
      add :downlink, :map
      add :mode, :string, null: false
      add :status, :string, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:transponders, [:satellite_id])

    create table(:alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :satellite_id, references(:satellites, on_delete: :nothing, type: :binary_id)
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)
      add :callsign, :string, null: false
      add :aos_at, :utc_datetime, null: false
      add :max_at, :utc_datetime, null: false
      add :los_at, :utc_datetime, null: false
      add :observer_lat, :float, null: false
      add :observer_lon, :float, null: false
      add :mhz, :float
      add :mhz_direction, :string, null: false, default: "down"
      add :mode, :string
      add :comment, :text
      add :grids, :string, null: false, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:satellite_id])
    create index(:alerts, [:user_id])
    create index(:alerts, [:aos_at])

    create table(:saved_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alert_id, references(:alerts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:saved_alerts, [:alert_id])
    create index(:saved_alerts, [:user_id])
    create unique_index(:saved_alerts, [:user_id, :alert_id])

    create table(:pass_filters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :digital_mod, :boolean, null: false, default: false
      add :fm_mod, :boolean, null: false, default: false
      add :linear_mod, :boolean, null: false, default: false
      add :min_el, :integer

      timestamps(type: :utc_datetime)
    end

    create unique_index(:pass_filters, [:user_id])

    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :enabled, :boolean, default: true
      add :description, :string

      timestamps(type: :utc_datetime)
    end
  end
end
