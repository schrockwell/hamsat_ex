defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

  @satellites Application.compile_env!(:hamsat, :satellites)

  def sync do
    for attrs <- known() do
      upsert_satellite!(attrs.number, attrs)
    end

    IO.puts("Synced #{length(known())} satellites")

    :ok
  end

  def first_satellite do
    Repo.one(from s in Sat, order_by: s.name, limit: 1)
  end

  def list_satellites do
    Repo.all(from s in Sat, order_by: s.name)
  end

  def list_satellites_and_stats do
    Repo.all(select_stats(from s in Sat, order_by: s.name))
  end

  defp select_stats(query) do
    from s in query,
      select: %{
        s
        | total_activation_count:
            fragment("coalesce((SELECT count(*) FROM alerts WHERE alerts.satellite_id = ?), 0)", s.id)
      }
  end

  def list_satellite_options do
    for sat <- list_satellites(), do: {sat.name, sat.id}
  end

  def upsert_satellite!(number, attrs) do
    Sat
    |> Repo.get_by(number: number)
    |> Repo.preload(:transponders)
    |> case do
      nil ->
        attrs |> Sat.upsert_changeset() |> Repo.insert!()

      satellite ->
        satellite |> Sat.upsert_changeset(attrs) |> Repo.update!()
    end
  end

  def get_satellite!(id) do
    Repo.get!(Sat, id)
  end

  def get_satellite_by_number!(number) do
    Repo.get_by!(Sat, number: number)
  end

  def known, do: @satellites
end
