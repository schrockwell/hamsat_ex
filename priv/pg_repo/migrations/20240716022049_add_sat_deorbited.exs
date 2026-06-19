defmodule Hamsat.Repo.Migrations.AddSatDeorbited do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :deorbited, :boolean, default: false, null: false
    end

    create index(:satellites, [:deorbited])
  end
end
