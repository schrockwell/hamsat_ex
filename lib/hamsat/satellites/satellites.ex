defmodule Hamsat.Satellites do
  use Hamsat, :repo

  alias Hamsat.Schemas.Sat

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

  def known do
    [
      %{name: "AO-7", number: 7530},
      %{name: "AO-27", number: 22825},
      %{name: "AO-73", number: 39444},
      %{name: "AO-91", number: 43017},
      %{name: "CAS-4A", number: 42761},
      %{name: "CAS-4B", number: 42759},
      %{name: "FO-29", number: 24278},
      %{name: "ISS", number: 25544},
      %{name: "JO-97", number: 43803},
      %{name: "LilacSat-2", number: 40908},
      %{name: "MO-112", number: 48868},
      %{name: "PO-101", number: 43678},
      %{name: "RS-44", number: 44909},
      %{name: "SO-50", number: 27607},
      %{name: "TO-108", number: 44881},
      %{name: "XW-2A", number: 40903}
    ]
    |> Enum.map(&Map.put_new(&1, :slug, &1.name))
  end
end
