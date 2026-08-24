defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  # A satellite is "popular" if an activation was posted for it within this window.
  @popular_window_days 30

  def sync_now do
    with {:ok, %HTTPoison.Response{status_code: 200, body: json}} <-
           HTTPoison.get("https://hamdata.ww1x.radio/amsat/satellites.json") do
      %{
        "data" => satellites_json,
        "updated" => updated_at
      } = Jason.decode!(json)

      satellites_json
      |> Enum.map(&satellite_attrs_from_json/1)
      |> Enum.map(&upsert_satellite!/1)
      |> Enum.each(&check_in_orbit/1)

      {:ok, Timex.parse!(updated_at, "{ISO:Extended}")}
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

  @doc """
  Per-satellite daily activation counts within the recent (30-day) window.

  Returns `%{satellite_id => %{"YYYY-MM-DD" => count}}` keyed by the date the
  alert was posted, for the activity sparklines on the satellites index.
  """
  def recent_activation_days do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@popular_window_days, :day)
      |> DateTime.truncate(:second)

    from(a in Alert,
      where: a.inserted_at >= ^cutoff,
      group_by: [a.satellite_id, fragment("date(?)", a.inserted_at)],
      select: {a.satellite_id, fragment("date(?)", a.inserted_at), count()}
    )
    |> Repo.all()
    |> Enum.group_by(fn {id, _date, _count} -> id end, fn {_id, date, count} -> {date, count} end)
    |> Map.new(fn {id, days} -> {id, Map.new(days)} end)
  end

  @doc """
  All-time activation stats for one satellite: total count, count within the
  recent (30-day) window, unique activator callsigns, and unique grids.
  """
  def activation_stats(sat) do
    cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@popular_window_days, :day)
      |> DateTime.truncate(:second)

    rows =
      Repo.all(
        from a in Alert,
          where: a.satellite_id == ^sat.id,
          select: {a.callsign, a.grids, a.inserted_at}
      )

    %{
      total: length(rows),
      recent: Enum.count(rows, fn {_, _, at} -> DateTime.compare(at, cutoff) != :lt end),
      rovers: rows |> Enum.map(fn {callsign, _, _} -> String.upcase(callsign) end) |> Enum.uniq() |> length(),
      grids: rows |> Enum.flat_map(fn {_, grids, _} -> grids end) |> Enum.uniq() |> length()
    }
  end

  @doc "Returns `%{satellite_id => most_recent_aos_at}` across all alerts."
  def last_activation_dates do
    from(a in Alert,
      group_by: a.satellite_id,
      select: {a.satellite_id, max(a.aos_at)}
    )
    |> Repo.all()
    |> Map.new()
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
    for {group, _description, sats} <- list_all_satellites_grouped() do
      {group, Enum.map(sats, &{&1.name, &1.id})}
    end
  end

  def upsert_satellite!(attrs) do
    # Match by NORAD number first; fall back to name in case a satellite has
    # been renumbered upstream (otherwise we'd insert a duplicate name).
    existing =
      Repo.get_by(Sat, number: attrs.number) ||
        Repo.get_by(Sat, name: attrs.name)

    existing
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

  def fetch_satellite_by_number(number) when is_integer(number) do
    case Repo.get_by(Sat, number: number) do
      %Sat{} = sat -> {:ok, preload_sat(sat)}
      nil -> {:error, :satellite_not_found}
    end
  end

  def fetch_satellite_by_number(number) when is_binary(number) do
    case Integer.parse(number) do
      {int, ""} -> fetch_satellite_by_number(int)
      _ -> {:error, :satellite_not_found}
    end
  end

  def fetch_satellite_by_number(_number), do: {:error, :satellite_not_found}

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
