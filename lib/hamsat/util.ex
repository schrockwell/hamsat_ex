defmodule Hamsat.Util do
  def erl_to_utc_datetime(erl_datetime) do
    erl_datetime
    |> NaiveDateTime.from_erl!()
    |> DateTime.from_naive!("Etc/UTC")
  end
end
