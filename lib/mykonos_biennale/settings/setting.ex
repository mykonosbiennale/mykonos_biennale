defmodule MykonosBiennale.Settings.Setting do
  use Ecto.Schema

  @primary_key {:key, :string, autogenerate: false}
  schema "settings" do
    field :value, :string
    timestamps(type: :utc_datetime)
  end
end
