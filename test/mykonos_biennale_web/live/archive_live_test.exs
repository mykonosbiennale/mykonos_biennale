defmodule MykonosBiennaleWeb.ArchiveLiveTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MykonosBiennale.ContentFixtures

  test "mounts /archive and lists biennales", %{conn: conn} do
    ContentFixtures.biennale_fixture(year: 2024, theme: "Test Theme 2024")
    ContentFixtures.biennale_fixture(year: 2023, theme: "Another Theme")

    {:ok, _lv, html} = live(conn, ~p"/archive")
    assert html =~ "Archive"
    assert html =~ "Test Theme 2024"
    assert html =~ "Another Theme"
  end

  test "shows empty state when no biennales", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/archive")
    assert html =~ "No biennales in the archive yet."
  end
end
