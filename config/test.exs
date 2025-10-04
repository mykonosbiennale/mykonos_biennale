import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mykonos_biennale, MykonosBiennale.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "mykonos_biennale_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mykonos_biennale, MykonosBiennaleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ggyzR+gtxL6Py5uMFyyYI0j9f4q6x2PrPzm3LeKv45O+KvtVZpNWJlIaPum0AkwX",
  server: false

# In test we don't send emails
config :mykonos_biennale, MykonosBiennale.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
