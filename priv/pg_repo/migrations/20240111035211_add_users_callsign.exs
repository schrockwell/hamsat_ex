defmodule Hamsat.Repo.Migrations.AddUsersCallsign do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :callsign, :string
    end

    create index(:users, [:callsign], unique: true)

    execute("UPDATE users SET callsign = latest_callsign", "")
  end
end
