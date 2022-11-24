defmodule Hamsat.Repo.Migrations.ChangeAlertMhz do
  use Ecto.Migration

  def up do
    alter table(:alerts) do
      add :mhz_direction, :string, null: false, default: "down"
    end

    rename table(:alerts), :downlink_mhz, to: :mhz
  end
end
