defmodule Hamsat.Repo.Migrations.AddSatNasaName do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :nasa_name, :string
    end

    flush()

    execute("UPDATE satellites SET nasa_name = name")

    alter table(:satellites) do
      modify(:nasa_name, :string, null: false)
    end
  end
end
