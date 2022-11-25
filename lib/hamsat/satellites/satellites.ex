defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

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

  def list_satellite_options do
    for sat <- list_satellites(), do: {sat.name, sat.id}
  end

  def upsert_satellite!(number, attrs) do
    case Repo.get_by(Sat, number: number) do
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

  #
  # SOURCES:
  # https://www.amsat.org/two-way-satellites/
  # https://www.amsat.org/linear-satellite-frequency-summary/
  #
  def known do
    [
      %{
        name: "AO-7",
        nasa_name: "AO-07",
        number: 7530,
        modulation: :linear,
        downlinks: [
          %{lower_mhz: 29.4000, upper_mhz: 29.5000},
          %{lower_mhz: 145.925, upper_mhz: 145.975}
        ],
        uplinks: [
          %{lower_mhz: 145.850, upper_mhz: 145.950},
          %{lower_mhz: 432.125, upper_mhz: 432.175}
        ]
      },
      %{
        name: "AO-27",
        number: 22825,
        modulation: :fm,
        downlinks: [%{lower_mhz: 436.795, upper_mhz: 436.795}],
        uplinks: [%{lower_mhz: 145.850, upper_mhz: 145.850}]
      },
      %{
        name: "AO-73",
        number: 39444,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.950, upper_mhz: 145.970}],
        uplinks: [%{lower_mhz: 435.130, upper_mhz: 435.150}]
      },
      %{
        name: "AO-91",
        number: 43017,
        modulation: :fm,
        downlinks: [%{lower_mhz: 145.96, upper_mhz: 145.96}],
        uplinks: [%{lower_mhz: 435.250, upper_mhz: 435.250}]
      },
      %{
        name: "CAS-4A",
        number: 42761,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.860, upper_mhz: 145.880}],
        uplinks: [%{lower_mhz: 435.210, upper_mhz: 435.230}]
      },
      %{
        name: "CAS-4B",
        number: 42759,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.915, upper_mhz: 145.935}],
        uplinks: [%{lower_mhz: 435.270, upper_mhz: 435.290}]
      },
      %{
        name: "FO-29",
        number: 24278,
        modulation: :linear,
        downlinks: [%{lower_mhz: 435.800, upper_mhz: 435.900}],
        uplinks: [%{lower_mhz: 145.900, upper_mhz: 146.000}]
      },
      %{
        name: "FO-99",
        number: 43937,
        modulation: :linear,
        downlinks: [%{lower_mhz: 435.880, upper_mhz: 435.910}],
        uplinks: [%{lower_mhz: 145.900, upper_mhz: 145.930}]
      },
      %{
        name: "GREENCUBE",
        number: 53106,
        modulation: :digital,
        downlinks: [%{lower_mhz: 435.310, upper_mhz: 435.310}],
        uplinks: [%{lower_mhz: 435.310, upper_mhz: 435.310}]
      },
      %{
        name: "ISS",
        number: 25544,
        modulation: :fm,
        downlinks: [%{lower_mhz: 437.8, upper_mhz: 437.8}],
        uplinks: [%{lower_mhz: 145.990, upper_mhz: 145.990}]
      },
      %{
        name: "JO-97",
        number: 43803,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.855, upper_mhz: 145.875}],
        uplinks: [%{lower_mhz: 435.100, upper_mhz: 435.120}]
      },
      %{
        name: "LilacSat-2",
        nasa_name: "LILACSAT-2",
        number: 40908,
        modulation: :fm,
        downlinks: [%{lower_mhz: 437.2, upper_mhz: 437.2}],
        uplinks: [%{lower_mhz: 144.350, upper_mhz: 144.350}]
      },
      # %{name: "MO-112", number: 48868, modulation: :fm},
      %{
        name: "PO-101",
        number: 43678,
        modulation: :fm,
        downlinks: [%{lower_mhz: 145.9, upper_mhz: 145.9}],
        uplinks: [%{lower_mhz: 437.500, upper_mhz: 437.500}]
      },
      %{
        name: "RS-44",
        number: 44909,
        modulation: :linear,
        downlinks: [%{lower_mhz: 435.610, upper_mhz: 435.670}],
        uplinks: [%{lower_mhz: 145.935, upper_mhz: 145.995}]
      },
      %{
        name: "SO-50",
        number: 27607,
        modulation: :fm,
        downlinks: [%{lower_mhz: 436.795, upper_mhz: 436.795}],
        uplinks: [%{lower_mhz: 145.850, upper_mhz: 145.850}]
      },
      %{
        name: "TO-108",
        number: 44881,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.915, upper_mhz: 145.935}],
        uplinks: [%{lower_mhz: 435.270, upper_mhz: 435.290}]
      },
      %{
        name: "XW-2A",
        number: 40903,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.665, upper_mhz: 145.685}],
        uplinks: [%{lower_mhz: 435.030, upper_mhz: 435.050}]
      },
      %{
        name: "XW-2C",
        number: 40906,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.795, upper_mhz: 145.815}],
        uplinks: [%{lower_mhz: 435.150, upper_mhz: 435.170}]
      },
      %{
        name: "EO-88",
        number: 42017,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.960, upper_mhz: 145.990}],
        uplinks: [%{lower_mhz: 435.015, upper_mhz: 435.045}]
      }
    ]
    |> Enum.map(&Map.put_new(&1, :slug, &1.name))
  end
end
