defmodule Hamsat.Repo.Migrations.AddMatchPreferences do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :prefer_cw_mode, :integer, null: false, default: 50
      add :prefer_ssb_mode, :integer, null: false, default: 50
      add :prefer_data_mode, :integer, null: false, default: 50
      add :prefer_fm_mode, :integer, null: false, default: 50
      add :prefer_dx_el, :integer, null: false, default: 45
      add :prefer_my_el, :integer, null: false, default: 45
    end
  end
end
