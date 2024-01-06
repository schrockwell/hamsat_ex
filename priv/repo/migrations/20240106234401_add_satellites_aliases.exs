defmodule Hamsat.Repo.Migrations.AddSatellitesAliases do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :aliases, {:array, :string}, null: false, default: "{}"
    end
  end
end
