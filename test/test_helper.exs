ExUnit.start(exclude: [:skip])
Ecto.Adapters.SQL.Sandbox.mode(MykonosBiennale.Repo, :manual)

# Suppress harmless Postgrex/DBConnection disconnect messages that occur
# when LiveView test processes exit before their sandbox DB connection
# is checked back in. The tests pass; these are just cleanup noise.
:logger.add_primary_filter(
  :silence_disconnect,
  {&MykonosBiennaleTest.LogFilter.filter/2, []}
)
