defmodule Hamsat.Repo.Migrations.AddTestAlerts do
  use Ecto.Migration

  def change do
    # Test alerts are created through the API only (for integration partners
    # developing against production) and are hidden from everyone but their
    # owner unless explicitly requested
    alter table(:alerts) do
      add :is_test, :boolean, null: false, default: false
    end
  end
end
