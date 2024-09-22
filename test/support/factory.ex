defmodule Hamsat.Factory do
  def guest_context(context, key) do
    Map.put(context, key, %Hamsat.Context{
      observer: Observer.create_from(0, 0, 0)
    })
  end

  def satellite(context, key, slug) do
    attrs = Hamsat.Satellites.known() |> Enum.find(&(&1.slug == slug))

    sat = Hamsat.Satellites.upsert_satellite!(attrs)

    Map.put(context, key, sat)
  end
end
