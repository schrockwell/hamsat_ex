defmodule Hamsat.Repo.Migrations.CreateSatellites do
  use Ecto.Migration

  def change do
    create table(:satellites, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :number, :integer, null: false
      add :name, :text, null: false
      add :slug, :text, null: false
      add :tle, :text

      timestamps(type: :utc_datetime)
    end

    create index(:satellites, :number, unique: true)
    create index(:satellites, :slug, unique: true)
    create index(:satellites, :name, unique: true)
  end
end
