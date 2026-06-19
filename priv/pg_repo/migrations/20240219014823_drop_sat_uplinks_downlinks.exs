defmodule Hamsat.Repo.Migrations.DropSatUplinksDownlinks do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      remove :uplinks
      remove :downlinks
    end
  end
end
