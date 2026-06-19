defmodule Hamsat.Repo.Migrations.AddSatStatus do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :in_orbit, :boolean, default: false, null: false
      add :is_active, :boolean, default: false, null: false

      remove :deorbited
    end

    create index(:satellites, [:in_orbit])
    create index(:satellites, [:is_active])
  end
end
