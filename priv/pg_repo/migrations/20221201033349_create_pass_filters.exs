defmodule Hamsat.Repo.Migrations.CreatePassFilters do
  use Ecto.Migration

  def change do
    create table(:pass_filters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id)
      add :digital_mod, :boolean, default: false, null: false
      add :fm_mod, :boolean, default: false, null: false
      add :linear_mod, :boolean, default: false, null: false
      add :min_el, :integer

      timestamps()
    end

    create index(:pass_filters, [:user_id], unique: true)
  end
end
