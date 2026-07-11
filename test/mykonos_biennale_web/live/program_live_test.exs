defmodule MykonosBiennaleWeb.ProgramLiveTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest
  alias MykonosBiennale.ContentFixtures

  test "mounts /program with biennale and events", %{conn: conn} do
    biennale =
      ContentFixtures.biennale_fixture(
        year: 2025,
        theme: "Program Theme",
        start_date: "2025-09-27",
        end_date: "2025-10-05"
      )

    ContentFixtures.event_fixture(title: "Program Event", type: "exhibition", biennale: biennale)

    {:ok, _lv, html} = live(conn, ~p"/program")
    assert html =~ "Program 2025"
    assert html =~ "Program Theme"
    assert html =~ "Program Event"
  end

  test "redirects to / when no current biennale", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/program")
  end

  test "shows upcoming message when no events", %{conn: conn} do
    ContentFixtures.biennale_fixture(year: 2025, theme: "Empty Program")

    {:ok, _lv, html} = live(conn, ~p"/program")
    assert html =~ "will be announced soon"
  end
end
