defmodule Hamsat.Alerts.AlertCounter do
  @moduledoc """
  Caches the all-time total number of activations in ETS for the site footer.

  The count excludes test alerts. It is seeded from the database on the first
  read and recounted whenever an activation is created or deleted (see
  `Hamsat.Alerts`).
  """

  use Hamsat, :repo

  alias Hamsat.Schemas.Alert

  @table __MODULE__
  @key :total

  def initialize do
    :ets.new(@table, [:public, :set, :named_table, read_concurrency: true])
  end

  @doc """
  Returns the total number of activations, counting from the database when no
  count is cached yet.
  """
  def total_count do
    case :ets.lookup(@table, @key) do
      [{@key, count}] -> count
      [] -> recount()
    end
  end

  @doc """
  Recounts from the database and caches the result.
  """
  def recount do
    count = Repo.aggregate(from(a in Alert, where: not a.is_test), :count)
    :ets.insert(@table, {@key, count})
    count
  end
end
