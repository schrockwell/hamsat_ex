defmodule Hamsat.Repo.Migrations.AddUserLatestMhzDirection do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :latest_mhz_direction, :string, null: false, default: "down"
    end
  end
end
