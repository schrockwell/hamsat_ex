defmodule Hamsat.Factory do
  # Satellites available to tests. Inserted directly (not via
  # Satellites.upsert_satellite!/1) because tests don't have a TLE on hand —
  # Sat.get_satrec/1 falls back to the satellite_ex bundled TLE database, which
  # covers these satellites by NORAD number.
  @known_satellites [
    %{name: "AO-7", number: 7530, modulations: [:linear]},
    %{name: "AO-73", number: 39444, modulations: [:linear]}
  ]

  def guest_context(context, key) do
    guest = %Hamsat.Context{location: %Hamsat.Coord{lat: 41.5, lon: -73.0}}
    Map.put(context, key, guest)
  end

  def satellite(context, key, name) do
    attrs =
      Enum.find(@known_satellites, &(&1.name == name)) ||
        raise ArgumentError, "unknown test satellite #{inspect(name)}"

    sat =
      Hamsat.Repo.get_by(Hamsat.Schemas.Sat, number: attrs.number) ||
        Hamsat.Repo.insert!(%Hamsat.Schemas.Sat{
          name: attrs.name,
          number: attrs.number,
          slug: attrs.name,
          nasa_name: attrs.name,
          modulations: attrs.modulations,
          in_orbit: true,
          is_active: true
        })

    Map.put(context, key, Hamsat.Repo.preload(sat, :transponders))
  end
end
