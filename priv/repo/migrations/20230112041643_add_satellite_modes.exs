defmodule Hamsat.Repo.Migrations.AddSatelliteModes do
  use Ecto.Migration

  def up do
    alter table(:satellites) do
      add :modes, {:array, :string}
    end

    execute("update satellites set modes = array[modulation]")

    alter table(:satellites) do
      remove :modulation
    end
  end

  def down do
    alter table(:satellites) do
      add :modulation, :string
    end

    execute("update satellites set modulation = modes[1]")

    alter table(:satellites) do
      remove :modes
    end
  end
end
