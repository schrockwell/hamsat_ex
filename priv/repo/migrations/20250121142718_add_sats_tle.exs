defmodule Hamsat.Repo.Migrations.AddSatsTle do
  use Ecto.Migration

  def change do
    alter table(:satellites) do
      add :tle, :string
    end
  end
end
