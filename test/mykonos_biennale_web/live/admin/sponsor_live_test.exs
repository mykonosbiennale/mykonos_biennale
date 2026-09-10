defmodule MykonosBiennaleWeb.Admin.SponsorLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures

  describe "Index" do
    test "lists sponsors with name, url and years", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      media = ContentFixtures.media_fixture(caption: "Test Sponsor Logo")

      Content.attach_media_to_entity(biennale, media,
        metadata: %{"role" => "sponsor", "name" => "VisitGreece", "url" => "https://visitgreece.gr"}
      )

      {:ok, _lv, html} = live(conn, ~p"/admin/sponsors")
      assert html =~ "VisitGreece"
      assert html =~ "https://visitgreece.gr"
      assert html =~ "2025"
    end

    test "shows empty state when no sponsors", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/sponsors")
      assert html =~ "No sponsors yet"
    end

    test "renders add sponsor form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/sponsors/new")
      html = lv |> element("#sponsor-modal") |> render()
      assert html =~ "Add Sponsor"
      assert html =~ "Sponsor name"
    end

    test "renders edit sponsor form with biennale checkboxes", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      _other = ContentFixtures.biennale_fixture(year: 2024)
      media = ContentFixtures.media_fixture(caption: "Edit Sponsor Logo")

      Content.attach_media_to_entity(biennale, media,
        metadata: %{"role" => "sponsor", "name" => "EditMe", "url" => "https://example.com"}
      )

      {:ok, lv, _html} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("EditMe")}/edit")
      html = lv |> element("#sponsor-edit-modal") |> render()
      assert html =~ "Edit Sponsor"
      assert html =~ "EditMe"
      assert html =~ "Upload a new logo to replace"
      assert html =~ "2025"
      assert html =~ "2024"
      assert html =~ "(sponsored — remove from the list)"
      assert html =~ "Check additional years to add this sponsor to them."
    end
  end
end
