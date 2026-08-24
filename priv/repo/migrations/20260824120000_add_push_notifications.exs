defmodule Hamsat.Repo.Migrations.AddPushNotifications do
  use Ecto.Migration

  def change do
    # Default off; users opt in from account settings
    alter table(:users) do
      add :push_reminders_enabled, :boolean, null: false, default: false
    end

    create table(:push_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :endpoint, :text, null: false
      add :p256dh, :text, null: false
      add :auth, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:push_subscriptions, [:user_id, :endpoint])

    # Set once the pre-pass reminder for this like has been pushed
    alter table(:saved_alerts) do
      add :notified_at, :utc_datetime
    end
  end
end
