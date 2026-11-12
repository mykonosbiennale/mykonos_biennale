defmodule MykonosBiennale.SettingsTest do
  use MykonosBiennale.DataCase, async: true

  alias MykonosBiennale.Settings

  test "current_biennale_year/0 reads the stored value" do
    :ok = Settings.put_current_biennale_year(2031)
    assert Settings.current_biennale_year() == 2031
  end

  test "put_current_biennale_year/1 overwrites the existing value" do
    :ok = Settings.put_current_biennale_year(2030)
    :ok = Settings.put_current_biennale_year(2032)
    assert Settings.current_biennale_year() == 2032
  end

  test "current_biennale_year/0 falls back to config when no row exists" do
    Repo.delete_all(MykonosBiennale.Settings.Setting)
    expected = Application.get_env(:mykonos_biennale, :current_biennale_year, 2021)
    assert Settings.current_biennale_year() == expected
  end
end
