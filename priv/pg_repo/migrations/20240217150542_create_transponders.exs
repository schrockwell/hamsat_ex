defmodule Hamsat.Repo.Migrations.CreateTransponders do
  use Ecto.Migration

  def change do
    create table(:transponders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :uplink, :map
      add :downlink, :map
      add :mode, :string, null: false
      add :status, :string, null: false
      add :satellite_id, references(:satellites, on_delete: :delete_all, type: :binary_id)
      add :notes, :text

      timestamps()
    end

    create index(:transponders, [:satellite_id])
  end
end
