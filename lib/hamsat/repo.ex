defmodule Hamsat.Repo do
  use Ecto.Repo,
    otp_app: :hamsat,
    adapter: Ecto.Adapters.Postgres
end
