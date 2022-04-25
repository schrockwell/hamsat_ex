defmodule Hamsat.Alerts.Pass do
  defstruct [:id, :info, :alerts, :sat, :observer, :hash]

  def progression(pass, now) do
    cond do
      Timex.compare(now, pass.info.aos.datetime) == -1 -> :upcoming
      Timex.compare(now, pass.info.los.datetime) == 1 -> :passed
      true -> :in_progress
    end
  end

  def equal?(pass1, pass2) do
    encode_hash(pass1) == encode_hash(pass2)
  end

  def put_hash(pass) do
    %{pass | hash: encode_hash(pass)}
  end

  def encode_hash(pass) do
    {:ok, grid} = Hamsat.Grid.encode(pass.observer.latitude_deg, pass.observer.longitude_deg, 6)
    max_unix = pass.info.max.datetime |> Hamsat.Util.erl_to_utc_datetime() |> DateTime.to_unix()
    satnum = pass.sat.number

    "#{satnum}-#{grid}-#{max_unix}"
  end

  def decode_hash!(hash) do
    [satnum, grid, max_unix] = String.split(hash, "-")

    satnum = String.to_integer(satnum)
    {:ok, {lat, lon}} = Hamsat.Grid.decode(grid)

    max_datetime_erl =
      max_unix
      |> String.to_integer()
      |> DateTime.from_unix!()
      |> DateTime.to_naive()
      |> NaiveDateTime.to_erl()

    %{
      satnum: satnum,
      lat: lat,
      lon: lon,
      max_datetime_erl: max_datetime_erl
    }
  end
end
