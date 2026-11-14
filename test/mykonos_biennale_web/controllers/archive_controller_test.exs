defmodule MykonosBiennaleWeb.ArchiveControllerTest do
  use MykonosBiennaleWeb.ConnCase

  alias MykonosBiennale.ContentFixtures

  test "lists biennales on /archive", %{conn: conn} do
    ContentFixtures.biennale_fixture(year: 2024, theme: "Test Theme 2024")
    ContentFixtures.biennale_fixture(year: 2023, theme: "Another Theme")

    html = conn |> get(~p"/archive") |> html_response(200)
    assert html =~ "Archive"
    assert html =~ "Test Theme 2024"
    assert html =~ "Another Theme"
  end

  test "shows empty state when no biennales", %{conn: conn} do
    html = conn |> get(~p"/archive") |> html_response(200)
    assert html =~ "No biennales in the archive yet."
  end

  test "does not crash on malformed dates", %{conn: conn} do
    ContentFixtures.biennale_fixture(
      year: 2022,
      theme: "Bad Dates",
      start_date: "not-a-date",
      end_date: "2022-07-01"
    )

    html = conn |> get(~p"/archive") |> html_response(200)
    assert html =~ "Bad Dates"
  end

  describe "dates" do
    test "shows a formatted date range when both dates are valid", %{conn: conn} do
      ContentFixtures.biennale_fixture(
        year: 2025,
        theme: "Dated",
        start_date: "2025-09-27",
        end_date: "2025-10-05"
      )

      html = conn |> get(~p"/archive") |> html_response(200)
      assert html =~ "September 27 – October 05, 2025"
    end

    test "omits the date line when dates are missing", %{conn: conn} do
      ContentFixtures.biennale_fixture(
        year: 2020,
        theme: "No Dates",
        start_date: nil,
        end_date: nil
      )

      html = conn |> get(~p"/archive") |> html_response(200)
      assert html =~ "No Dates"
      refute html =~ "– "
    end

    test "omits the date line when only one date is set", %{conn: conn} do
      ContentFixtures.biennale_fixture(
        year: 2019,
        theme: "Half Dates",
        start_date: "2019-07-01",
        end_date: nil
      )

      html = conn |> get(~p"/archive") |> html_response(200)
      assert html =~ "Half Dates"
      refute html =~ "July 01"
    end

    test "omits the date line when the end date is malformed", %{conn: conn} do
      ContentFixtures.biennale_fixture(
        year: 2018,
        theme: "Bad End",
        start_date: "2018-07-01",
        end_date: "31/12/2018"
      )

      html = conn |> get(~p"/archive") |> html_response(200)
      assert html =~ "Bad End"
      refute html =~ "July 01"
    end
  end

  describe "images" do
    test "renders a card for a biennale with no media", %{conn: conn} do
      ContentFixtures.biennale_fixture(year: 2017, theme: "No Media Edition")

      html = conn |> get(~p"/archive") |> html_response(200)
      assert html =~ "No Media Edition"
      assert html =~ "2017"
      # Cards fall back to the gradient placeholder rather than an image.
      assert html =~ "from-gray-800 to-black"
      refute html =~ "background-image"
    end
  end
end
