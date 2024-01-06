defmodule Hamsat.Repo.Migrations.AddUsersTimezone do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :timezone, :string, default: "Etc/UTC", null: false
    end
  end
end
