defmodule MykonosBiennale.Settings do
  @moduledoc """
  Key/value application settings persisted in the settings table, such as the current biennale year.
  """

  alias MykonosBiennale.Repo
  alias MykonosBiennale.Settings.Setting

  @current_biennale_year "current_biennale_year"

  def current_biennale_year do
    case Repo.get(Setting, @current_biennale_year) do
      %Setting{value: value} -> String.to_integer(value)
      nil -> Application.get_env(:mykonos_biennale, :current_biennale_year, 2021)
    end
  end

  def put_current_biennale_year(year) when is_integer(year) do
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      Setting,
      [
        %{
          key: @current_biennale_year,
          value: Integer.to_string(year),
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: {:replace, [:value, :updated_at]},
      conflict_target: :key
    )

    :ok
  end
end
