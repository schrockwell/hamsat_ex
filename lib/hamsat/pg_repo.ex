defmodule Hamsat.PgRepo do
  use Ecto.Repo,
    otp_app: :hamsat,
    adapter: Ecto.Adapters.Postgres
end
