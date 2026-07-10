import Config
config :mykonos_biennale, Oban, testing: :manual

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mykonos_biennale, MykonosBiennale.Repo,
  url:
    System.get_env("TEST_DATABASE_URL") ||
      "ecto://thanos@localhost/mykonos_biennale_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  ssl: false

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mykonos_biennale, MykonosBiennaleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "VofmwjG6yMLfajzXpULi8lc2eiAAUZwN5V47w1b3NHfASQJ35BbZz7OwMxCS3lrV",
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
