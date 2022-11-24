defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

  def list_satellites do
    Repo.all(
      from s in Sat,
        order_by: s.name
    )
  end

  def upsert_satellite!(number, attrs) do
    case Repo.get_by(Sat, number: number) do
      nil ->
        attrs |> Sat.upsert_changeset() |> Repo.insert!()

      satellite ->
        satellite |> Sat.upsert_changeset(attrs) |> Repo.update!()
    end
  end

  def get_satellite!(slug) do
    Repo.get_by!(Sat, slug: slug)
  end

  def get_satellite_by_number!(number) do
    Repo.get_by!(Sat, number: number)
  end

  # SOURCE: https://www.amsat.org/two-way-satellites/
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
        ]
      },
      %{
        name: "AO-27",
        number: 22825,
        modulation: :fm,
        downlinks: [%{lower_mhz: 436.795, upper_mhz: 436.795}]
      },
      %{
        name: "AO-73",
        number: 39444,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.950, upper_mhz: 145.970}]
      },
      %{
        name: "AO-91",
        number: 43017,
        modulation: :fm,
        downlinks: [%{lower_mhz: 145.96, upper_mhz: 145.96}]
      },
      %{
        name: "CAS-4A",
        number: 42761,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.860, upper_mhz: 145.880}]
      },
      %{
        name: "CAS-4B",
        number: 42759,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.915, upper_mhz: 145.935}]
      },
      %{
        name: "FO-29",
        number: 24278,
        modulation: :linear,
        downlinks: [%{lower_mhz: 435.800, upper_mhz: 435.900}]
      },
      %{
        name: "FO-99",
        number: 43937,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.900, upper_mhz: 145.930}]
      },
      %{
        name: "GREENCUBE",
        number: 53106,
        modulation: :digital,
        downlinks: [%{lower_mhz: 435.310, upper_mhz: 435.310}]
      },
      %{
        name: "ISS",
        number: 25544,
        modulation: :fm,
        downlinks: [%{lower_mhz: 437.8, upper_mhz: 437.8}]
      },
      %{
        name: "JO-97",
        number: 43803,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.855, upper_mhz: 145.875}]
      },
      %{
        name: "LilacSat-2",
        nasa_name: "LILACSAT-2",
        number: 40908,
        modulation: :fm,
        downlinks: [%{lower_mhz: 437.2, upper_mhz: 437.2}]
      },
      # %{name: "MO-112", number: 48868, modulation: :fm},
      %{
        name: "PO-101",
        number: 43678,
        modulation: :fm,
        downlinks: [%{lower_mhz: 145.9, upper_mhz: 145.9}]
      },
      %{
        name: "RS-44",
        number: 44909,
        modulation: :linear,
        downlinks: [%{lower_mhz: 435.610, upper_mhz: 435.670}]
      },
      %{
        name: "SO-50",
        number: 27607,
        modulation: :fm,
        downlinks: [%{lower_mhz: 436.795, upper_mhz: 436.795}]
      },
      %{
        name: "TO-108",
        number: 44881,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.915, upper_mhz: 145.935}]
      },
      %{
        name: "XW-2A",
        number: 40903,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.665, upper_mhz: 145.685}]
      },
      %{
        name: "XW-2C",
        number: 40906,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.795, upper_mhz: 145.815}]
      },
      %{
        name: "EO-88",
        number: 42017,
        modulation: :linear,
        downlinks: [%{lower_mhz: 145.960, upper_mhz: 145.990}]
      }
    ]
    |> Enum.map(&Map.put_new(&1, :slug, &1.name))
  end
end
