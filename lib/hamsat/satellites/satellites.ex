defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

  @satellites Application.compile_env!(:hamsat, :satellites)

  def sync do
    for attrs <- known() do
      upsert_satellite!(attrs.number, attrs)
    end

    known()
    |> Enum.map(& &1.number)
    |> deorbit_satellites()

    IO.puts("Synced #{length(known())} satellites")

    :ok
  end

  def first_satellite do
    sat_query()
    |> limit(1)
    |> Repo.one()
    |> preload_sat()
  end

  def list_satellites do
    Repo.all(sat_query())
  end

  def list_satellites_and_stats do
    sat_query()
    |> select_stats()
    |> Repo.all()
  end

  defp sat_query do
    from s in Sat, where: not s.deorbited, order_by: s.name
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

  defp deorbit_satellites(known_satnums) do
    Repo.update_all(from(s in Sat, where: s.number in ^known_satnums), set: [deorbited: false])
    Repo.update_all(from(s in Sat, where: s.number not in ^known_satnums), set: [deorbited: true])
  end

  def get_satellite!(id) do
    Sat |> Repo.get!(id) |> preload_sat()
  end

  def get_satellite_by_number!(number) do
    Sat |> Repo.get_by!(number: number) |> preload_sat()
  end

  def known, do: @satellites

  def preload_sat(sat) do
    Repo.preload(sat, :transponders)
  end
end
