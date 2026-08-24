defmodule Hamsat.Repo.Migrations.AddActivationChat do
  use Ecto.Migration

  def change do
    # Default on for new and existing users
    alter table(:users) do
      add :prefer_chat_enabled, :boolean, null: false, default: true
    end

    # Default off so existing alerts do not get chat retroactively; new alerts
    # set this explicitly from the activation form
    alter table(:alerts) do
      add :chat_enabled, :boolean, null: false, default: false
    end

    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alert_id, references(:alerts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:alert_id])
  end
end
