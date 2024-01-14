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

  def trim_params(params, fields \\ :all) do
    # Build stringy version of fields
    fields = if is_list(fields), do: fields ++ Enum.map(fields, &to_string/1), else: fields

    Map.new(params, fn {k, v} ->
      if is_binary(v) and (fields == :all or k in fields) do
        {k, String.trim(v)}
      else
        {k, v}
      end
    end)
  end
end
