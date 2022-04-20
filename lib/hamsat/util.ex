defmodule Hamsat.Util do
  def erl_to_utc_datetime(erl_datetime) do
    erl_datetime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end

  def utc_datetime_to_erl(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
  end
end
