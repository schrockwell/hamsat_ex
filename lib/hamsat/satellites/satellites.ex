defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

  def start_sync do
    Task.start(fn -> sync_now() end)
  end

  def sync_now do
    with {:ok, %HTTPoison.Response{status_code: 200, body: json}} <-
           HTTPoison.get("https://hamdata.ww1x.radio/amsat/satellites.json") do
      satellites_json = Jason.decode!(json)["data"]

      upserted_sats =
        satellites_json
        |> Enum.map(&satellite_attrs_from_json/1)
        |> Enum.filter(&(&1.status == :active || &1.status == :conflicting))
        |> Enum.map(&upsert_satellite!/1)

      upserted_sats
      |> Enum.map(& &1.number)
      |> deorbit_satellites()
    end
  end

  defp satellite_attrs_from_json(json) do
    modulations =
      json
      |> Map.get("meta", %{})
      |> Map.get("transponders", [])
      |> Enum.flat_map(fn
        %{"mode" => "digital"} -> [:digital]
        %{"mode" => "fm"} -> [:fm]
        %{"mode" => "linear"} -> [:linear]
        _ -> []
      end)
      |> Enum.uniq()

    transponders =
      json
      |> Map.get("transponders", [])
      |> Enum.map(fn xpdr ->
        %{
          mode: String.to_atom(xpdr["mode"]),
          status: String.to_atom(xpdr["status"]),
          downlink: %{
            lower_mhz: xpdr["downlink"]["min"],
            upper_mhz: xpdr["downlink"]["max"]
          },
          uplink: %{
            lower_mhz: xpdr["uplink"]["min"],
            upper_mhz: xpdr["uplink"]["max"]
          }
        }
      end)

    %{
      name: json["name"],
      nasa_name: json["name"],
      slug: json["name"],
      number: json["number"],
      status: String.to_atom(json["status"]),
      modulations: modulations,
      transponders: transponders,
      aliases: Map.get(json, "aliases", [])
    }
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

  def upsert_satellite!(attrs) do
    Sat
    |> Repo.get_by(number: attrs.number)
    |> Repo.preload(:transponders)
    |> case do
      nil ->
        attrs |> Sat.upsert_changeset() |> Repo.insert!()

      satellite ->
        satellite |> Sat.upsert_changeset(attrs) |> Repo.update!()
    end
  end

  defp deorbit_satellites(active_satnums) do
    Repo.update_all(from(s in Sat, where: s.number in ^active_satnums), set: [deorbited: false])
    Repo.update_all(from(s in Sat, where: s.number not in ^active_satnums), set: [deorbited: true])
  end

  def get_satellite!(id) do
    Sat |> Repo.get!(id) |> preload_sat()
  end

  def get_satellite_by_number!(number) do
    Sat |> Repo.get_by!(number: number) |> preload_sat()
  end

  def preload_sat(sat) do
    Repo.preload(sat, :transponders)
  end
end
