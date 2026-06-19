defmodule Hamsat.Repo.Migrations.CreateSavedAlerts do
  use Ecto.Migration

  def change do
    create table(:saved_alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alert_id, references(:alerts, on_delete: :delete_all, type: :binary_id)
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)

      timestamps()
    end

    create index(:saved_alerts, [:alert_id])
    create index(:saved_alerts, [:user_id])
    create index(:saved_alerts, [:user_id, :alert_id], unique: true)
  end
end
