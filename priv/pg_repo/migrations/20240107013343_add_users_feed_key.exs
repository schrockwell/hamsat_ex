defmodule Hamsat.Repo.Migrations.AddUsersFeedKey do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "DROP EXTENSION \"uuid-ossp\"")

    alter table(:users) do
      add :feed_key, :string, null: false, default: fragment("uuid_generate_v4()")
    end
  end
end
