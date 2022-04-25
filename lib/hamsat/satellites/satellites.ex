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
      %{name: "AO-7", number: 7530, modulation: :linear},
      %{name: "AO-27", number: 22825, modulation: :fm},
      %{name: "AO-73", number: 39444, modulation: :linear},
      %{name: "AO-91", number: 43017, modulation: :fm},
      %{name: "CAS-4A", number: 42761, modulation: :linear},
      %{name: "CAS-4B", number: 42759, modulation: :linear},
      %{name: "FO-29", number: 24278, modulation: :linear},
      %{name: "ISS", number: 25544, modulation: :fm},
      %{name: "JO-97", number: 43803, modulation: :linear},
      %{name: "LilacSat-2", number: 40908, modulation: :fm},
      # %{name: "MO-112", number: 48868, modulation: :fm},
      %{name: "PO-101", number: 43678, modulation: :fm},
      %{name: "RS-44", number: 44909, modulation: :linear},
      %{name: "SO-50", number: 27607, modulation: :fm},
      %{name: "TO-108", number: 44881, modulation: :linear},
      %{name: "XW-2A", number: 40903, modulation: :linear}
    ]
    |> Enum.map(&Map.put_new(&1, :slug, &1.name))
  end
end
