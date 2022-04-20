defmodule Hamsat.Alerts do
  use Hamsat, :repo

  alias Hamsat.Context
  alias Hamsat.Schemas.Alert
  alias Hamsat.Schemas.Sat

  @doc """
  Returns a sorted list of satellite passes for one satellite.
  """
  def list_passes(context, sat, opts \\ []) do
    observer = Context.get_observer(context)
    satrec = Sat.get_satrec(sat)
    count = opts[:count] || 1

    satrec
    |> Satellite.list_passes(count, observer, :calendar.universal_time())
    |> Enum.map(&Map.put(&1, :sat, sat))
    |> Enum.sort_by(& &1.aos.datetime)
  end

  @doc """
  Returns a sorted list of satellite passes for many satellites.
  """
  def list_all_passes(context, sats, opts \\ []) do
    sats
    |> Enum.map(fn sat ->
      Task.async(fn ->
        list_passes(context, sat, opts)
      end)
    end)
    |> Task.await_many()
    |> List.flatten()
    |> Enum.sort_by(& &1.aos.datetime)
  end

  def create_alert(context, pass, attrs \\ %{}) do
    context
    |> Alert.insert_changeset(pass, attrs)
    |> Repo.insert()
  end
end
