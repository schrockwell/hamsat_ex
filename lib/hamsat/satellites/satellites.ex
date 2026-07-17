defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  # A satellite is "popular" if an activation was posted for it within this window.
  @popular_window_days 30

  def sync_now do
    with {:ok, %HTTPoison.Response{status_code: 200, body: json}} <-
           HTTPoison.get("https://hamdata.ww1x.radio/amsat/satellites.json") do
      satellites_json = Jason.decode!(json)["data"]

      satellites_json
      |> Enum.map(&satellite_attrs_from_json/1)
      |> Enum.map(&upsert_satellite!/1)
      |> Enum.map(&check_in_orbit/1)
    end
  end

  def in_orbit?(sat) do
    satrec = Sat.get_satrec(sat)
    observer = Hamsat.Coord.to_observer(%Hamsat.Coord{lat: 0, lon: 0})
    Satellite.current_position(satrec, observer, magnitude?: false)
    true
  rescue
    _ -> false
  end

  defp satellite_attrs_from_json(json) do
    xpdr_json =
      json
      |> Map.get("meta", %{})
      |> Map.get("transponders", [])

    modulations =
      xpdr_json
      |> Enum.flat_map(fn
        %{"mode" => "digital"} -> [:digital]
        %{"mode" => "fm"} -> [:fm]
        %{"mode" => "linear"} -> [:linear]
        _ -> []
      end)
      |> Enum.uniq()

    transponders =
      xpdr_json
      |> Enum.map(fn xpdr ->
        %{
          mode:
            case xpdr do
              %{"mode" => "digital"} -> :digital
              %{"mode" => "fm"} -> :fm
              %{"mode" => "linear", "inverting" => true} -> :linear
              %{"mode" => "linear", "inverting" => false} -> :linear_non_inv
            end,
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
      is_active: json["status"] == "active" || json["status"] == "conflicting",
      modulations: modulations,
      transponders: transponders,
      aliases: Map.get(json, "aliases", []),
      tle: json |> Map.get("tle", []) |> Enum.join("\n")
    }
  end

  def first_popular_satellite do
    sat =
      popular_sats_query()
      |> limit(1)
      |> Repo.one()

    sat =
      sat ||
        all_sats_in_orbit_query()
        |> limit(1)
        |> Repo.one()

    sat
    |> put_popular()
    |> preload_sat()
  end

  def list_popular_satellites do
    popular_sats_query()
    |> Repo.all()
    |> Enum.map(&put_popular/1)
  end

  def list_in_orbit_satellites do
    all_sats_in_orbit_query()
    |> Repo.all()
    |> Enum.map(&put_popular/1)
  end

  def list_all_satellites_grouped do
    list_in_orbit_satellites()
    |> group_sats()
  end

  def list_satellites_and_stats do
    all_sats_in_orbit_query()
    |> select_stats()
    |> Repo.all()
    |> Enum.map(&put_popular/1)
  end

  defp all_sats_in_orbit_query do
    from s in Sat,
      as: :sat,
      where: s.in_orbit,
      order_by: s.name,
      select_merge: %{recent_activation_count: subquery(recent_alert_count_query())}
  end

  defp popular_sats_query do
    from s in all_sats_in_orbit_query(), where: exists(recent_alerts_query())
  end

  defp recent_alerts_query do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@popular_window_days, :day)
      |> DateTime.truncate(:second)

    from a in Alert,
      where: a.satellite_id == parent_as(:sat).id,
      where: a.inserted_at >= ^cutoff
  end

  defp recent_alert_count_query do
    from a in recent_alerts_query(), select: count()
  end

  defp put_popular(nil), do: nil
  defp put_popular(sat), do: %{sat | is_popular: sat.recent_activation_count > 0}

  def group_sats(sats) do
    [
      {"Active", "Activated within the past 30 days", Enum.filter(sats, &(&1.in_orbit and &1.is_popular))},
      {"Inactive", "Not activated within the past 30 days", Enum.filter(sats, &(&1.in_orbit and not &1.is_popular))}
    ]
  end

  defp select_stats(query) do
    from s in query,
      select_merge: %{
        total_activation_count:
          fragment("coalesce((SELECT count(*) FROM alerts WHERE alerts.satellite_id = ?), 0)", s.id)
      }
  end

  def list_satellite_options do
    for {group, sats} <- list_all_satellites_grouped() do
      {group, Enum.map(sats, &{&1.name, &1.id})}
    end
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

  def get_satellite!(id) do
    Sat |> Repo.get!(id) |> preload_sat()
  end

  def get_satellite_by_number!(number) do
    Sat |> Repo.get_by!(number: number) |> preload_sat()
  end

  def preload_sat(sat) do
    Repo.preload(sat, :transponders)
  end

  def check_in_orbit(sat) do
    is_in_orbit = in_orbit?(sat)

    if is_in_orbit != sat.in_orbit do
      sat
      |> Ecto.Changeset.change(in_orbit: is_in_orbit)
      |> Repo.update!()
    else
      sat
    end
  end
end
