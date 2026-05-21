defmodule MykonosBiennale.Repo do
  use Ecto.Repo,
    otp_app: :mykonos_biennale,
    adapter: Ecto.Adapters.Postgres
end
