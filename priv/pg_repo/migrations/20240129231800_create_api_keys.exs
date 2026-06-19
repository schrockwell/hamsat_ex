defmodule Hamsat.Repo.Migrations.CreateApiKeys do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :enabled, :boolean, default: true
      add :description, :string

      timestamps()
    end
  end
end
