defmodule Hamsat.Repo.Migrations.AddUsersTimeFormat do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :time_format, :string, default: "24h"
    end
  end
end
