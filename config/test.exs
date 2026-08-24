import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :hamsat, Hamsat.Repo,
  database: "hamsat_test#{System.get_env("MIX_TEST_PARTITION")}.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hamsat, HamsatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "6zFDi5VREv9iRVS5hUv4MbgyOQgDeKBySLNK5/uWzBL6009SpdvkaQ/OmVI7SAVu",
  server: false

# In test we don't send emails.
config :hamsat, Hamsat.Mailer, adapter: Swoosh.Adapters.Test

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :hamsat, mapbox_access_token: "test-token"

# Web Push (VAPID) keys for tests (same throwaway pair as dev)
config :hamsat, :vapid,
  subject: "mailto:support@hams.at",
  public_key: "BEUcb29kKrRHFcbDc7a_Lux1gsY-JFSHuFC0RckBn79waLkjAY4ch2B24Vv_DZqUXDkHhkoRdhAZr7pINkzxk1c",
  private_key: "PFfUdUXjSrTRMglxJrL0VbwHzqxzMeOCzanvSlvHS3M"
