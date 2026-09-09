defmodule HamsatWeb.ViewHelpersTest do
  use ExUnit.Case, async: true

  import HamsatWeb.ViewHelpers

  test "delimited_integer/1 inserts US thousands separators" do
    assert delimited_integer(0) == "0"
    assert delimited_integer(999) == "999"
    assert delimited_integer(1000) == "1,000"
    assert delimited_integer(12345) == "12,345"
    assert delimited_integer(1_234_567) == "1,234,567"
  end
end
