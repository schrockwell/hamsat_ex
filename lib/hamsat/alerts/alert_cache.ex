defmodule Hamsat.Alerts.AlertCache do
  @moduledoc """
  Caches alert lookups for the read API in ETS.

  Entries expire after `@ttl_ms`, and the whole cache is invalidated whenever
  an alert is created, updated, or deleted (see `Hamsat.Alerts`) and whenever
  satellite TLEs are synced, since the workable window and max elevation of an
  alert depend on them. Less important changes, like the like count, are left
  to the TTL.

  Keys are arbitrary terms. Callers are responsible for including everything
  the cached value depends on in the key (e.g. the requesting user).
  """
  require Logger

  @table __MODULE__
  @ttl_ms :timer.minutes(5)

  def initialize do
    :ets.new(@table, [:public, :set, :named_table, read_concurrency: true])
  end

  @doc """
  Returns the cached value for `key` as `{:ok, value}`, or `:miss` when there
  is none or it has expired.
  """
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, expires_at, value}] ->
        if expires_at > now() do
          Logger.debug("AlertCache HIT for #{inspect(key)}")
          {:ok, value}
        else
          Logger.debug("AlertCache EXPIRED for #{inspect(key)}")
          :miss
        end

      [] ->
        Logger.debug("AlertCache MISS for #{inspect(key)}")
        :miss
    end
  end

  @doc """
  Caches `value` under `key` and returns it.

  Options:

    * `:ttl` - milliseconds until the entry expires (default 5 minutes)
  """
  def put(key, value, opts \\ []) do
    ttl_ms = Keyword.get(opts, :ttl, @ttl_ms)
    :ets.insert(@table, {key, now() + ttl_ms, value})
    value
  end

  @doc """
  Returns the cached value for `key`, computing and caching it with `fun` on a
  miss.
  """
  def fetch(key, fun) when is_function(fun, 0) do
    case get(key) do
      {:ok, value} -> value
      :miss -> put(key, fun.())
    end
  end

  @doc """
  Drops every entry. Called whenever alerts change.
  """
  def invalidate do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Drops expired entries, returning how many were removed.
  """
  def purge do
    cutoff = now()

    # :ets.fun2ms(fn {_, expires_at, _} -> expires_at <= cutoff end)
    match_spec = [{{:_, :"$1", :_}, [], [{:"=<", :"$1", cutoff}]}]

    :ets.select_delete(@table, match_spec)
  end

  defp now, do: System.monotonic_time(:millisecond)
end
