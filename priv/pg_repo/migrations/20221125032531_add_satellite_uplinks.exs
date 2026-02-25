defmodule Hamsat.Repo.Migrations.AddSatelliteUplinks do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :uplinks, :json, null: false, default: "[]"
    end
  end
end
