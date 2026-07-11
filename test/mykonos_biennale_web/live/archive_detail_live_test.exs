defmodule MykonosBiennaleWeb.ArchiveDetailLiveTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MykonosBiennale.ContentFixtures

  test "mounts /archive/:year with biennale and events", %{conn: conn} do
    biennale =
      ContentFixtures.biennale_fixture(
        year: 2024,
        theme: "Archive Theme",
        start_date: "2024-09-27",
        end_date: "2024-10-05",
        statement: "A statement."
      )

    ContentFixtures.event_fixture(title: "Archived Event", type: "exhibition", biennale: biennale)

    {:ok, _lv, html} = live(conn, ~p"/archive/2024")
    assert html =~ "Archive Theme"
    assert html =~ "2024"
    assert html =~ "Program"
    assert html =~ "Archived Event"
  end

  test "shows statement section when present", %{conn: conn} do
    ContentFixtures.biennale_fixture(
      year: 2023,
      theme: "Statement Test",
      statement: "Unique statement text."
    )

    {:ok, _lv, html} = live(conn, ~p"/archive/2023")
    assert html =~ "Unique statement text."
  end

  test "shows no events message when biennale has no events", %{conn: conn} do
    ContentFixtures.biennale_fixture(year: 2022, theme: "Empty Biennale")

    {:ok, _lv, html} = live(conn, ~p"/archive/2022")
    assert html =~ "No events have been added to this biennale yet."
  end

  test "redirects to /archive for unknown year", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/archive"}}} = live(conn, ~p"/archive/1999")
  end
end
