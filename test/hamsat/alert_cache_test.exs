defmodule Hamsat.Alerts.AlertCacheTest do
  use ExUnit.Case

  alias Hamsat.Alerts.AlertCache

  setup do
    AlertCache.invalidate()
    :ok
  end

  test "get/1 misses on unknown keys" do
    assert AlertCache.get(:nope) == :miss
  end

  test "put/2 stores a value that get/1 returns" do
    assert AlertCache.put(:key, :value) == :value
    assert AlertCache.get(:key) == {:ok, :value}
  end

  test "fetch/2 computes on a miss and reuses on a hit" do
    assert AlertCache.fetch(:key, fn -> 1 end) == 1
    assert AlertCache.fetch(:key, fn -> flunk("should not be called") end) == 1
  end

  test "expired entries miss" do
    AlertCache.put(:key, :value, ttl: -1)
    assert AlertCache.get(:key) == :miss
  end

  test "invalidate/0 drops everything" do
    AlertCache.put(:a, 1)
    AlertCache.put(:b, 2)

    assert AlertCache.invalidate() == :ok
    assert AlertCache.get(:a) == :miss
    assert AlertCache.get(:b) == :miss
  end

  test "purge/0 drops only expired entries" do
    AlertCache.put(:live, 1)
    AlertCache.put(:expired, 2, ttl: -1)

    assert AlertCache.purge() == 1
    assert AlertCache.get(:live) == {:ok, 1}
    assert AlertCache.get(:expired) == :miss
  end
end
