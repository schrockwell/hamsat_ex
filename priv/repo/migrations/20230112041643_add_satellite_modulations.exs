defmodule Hamsat.Repo.Migrations.AddSatelliteModulations do
  use Ecto.Migration

  def up do
    alter table(:satellites) do
      add :modulations, {:array, :string}
    end

    execute("update satellites set modulations = array[modulation]")

    alter table(:satellites) do
      remove :modulation
    end
  end

  def down do
    alter table(:satellites) do
      add :modulation, :string
    end

    execute("update satellites set modulation = modulations[1]")

    alter table(:satellites) do
      remove :modulations
    end
  end
end
