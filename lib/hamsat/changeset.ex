defmodule Hamsat.Changeset do
  import Ecto.Changeset

  def format_callsign(changeset, field \\ :callsign) do
    if callsign = get_change(changeset, field) do
      new_callsign = callsign |> String.trim() |> String.upcase()
      put_change(changeset, field, new_callsign)
    else
      changeset
    end
  end
end
