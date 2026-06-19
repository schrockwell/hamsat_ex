defmodule Hamsat.Repo.Migrations.AddAlertGrids do
  use Ecto.Migration

  import Ecto.Changeset

  alias Hamsat.Grid
  alias Hamsat.Repo
  alias Hamsat.Schemas.Alert

  def up do
    alter table(:alerts) do
      add :grids, {:array, :string}
    end

    flush()

    for alert <- Repo.all(Alert) do
      alert
      |> change(%{grids: [Grid.encode!(alert.observer_lat, alert.observer_lon, 4)]})
      |> Repo.update!()
    end

    flush()

    alter table(:alerts) do
      modify :grids, {:array, :string}, null: false
    end
  end

  def down do
    alter table(:alerts) do
      remove :grids
    end
  end
end
