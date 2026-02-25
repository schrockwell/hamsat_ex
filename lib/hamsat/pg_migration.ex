defmodule Hamsat.PgMigration do
  @moduledoc """
  One-time migration from PostgreSQL to SQLite.

  Reads all data from `Hamsat.PgRepo` (Postgres) and inserts it into
  `Hamsat.Repo` (SQLite). Both repos must be started before calling `run/0`.

  ## Usage

      # In iex with both repos configured and started:
      Hamsat.PgMigration.run()
  """

  require Logger

  @doc """
  Migrates all data from PgRepo to Repo.
  Tables are migrated in FK-dependency order.
  """
  def run do
    Hamsat.PgRepo.start_link()
    Logger.info("Starting PostgreSQL → SQLite migration")

    # clear all existing data in the target SQLite tables
    Hamsat.Repo.delete_all(Hamsat.Accounts.UserToken)
    Hamsat.Repo.delete_all(Hamsat.Accounts.User)
    Hamsat.Repo.delete_all(Hamsat.Schemas.Transponder)
    Hamsat.Repo.delete_all(Hamsat.Schemas.Sat)
    Hamsat.Repo.delete_all(Hamsat.Schemas.Alert)
    Hamsat.Repo.delete_all(Hamsat.Schemas.SavedAlert)
    Hamsat.Repo.delete_all(Hamsat.Schemas.PassFilter)
    Hamsat.Repo.delete_all(Hamsat.Schemas.APIKey)

    migrate_table("users", Hamsat.Accounts.User)
    migrate_table("users_tokens", Hamsat.Accounts.UserToken)
    migrate_table("satellites", Hamsat.Schemas.Sat)
    migrate_table("transponders", Hamsat.Schemas.Transponder)
    migrate_table("alerts", Hamsat.Schemas.Alert)
    migrate_table("saved_alerts", Hamsat.Schemas.SavedAlert)
    migrate_table("pass_filters", Hamsat.Schemas.PassFilter)
    migrate_table("api_keys", Hamsat.Schemas.APIKey)

    Logger.info("Migration complete")
    :ok
  end

  defp migrate_table(table_name, schema) do
    rows =
      schema
      |> Hamsat.PgRepo.all()
      |> Enum.map(&to_insertable_map(schema, &1))

    count =
      rows
      |> Enum.chunk_every(100)
      |> Enum.reduce(0, fn batch, acc ->
        {n, _} = Hamsat.Repo.insert_all(schema, batch)
        acc + n
      end)

    Logger.info("Migrated #{count} rows into #{table_name}")
  end

  defp to_insertable_map(schema, row) do
    fields = schema.__schema__(:fields)
    embeds = schema.__schema__(:embeds)

    field_map = Map.take(row, fields)
    embed_map = Map.take(row, embeds)

    Map.merge(field_map, embed_map)
  end
end
