defmodule MykonosBiennaleWeb.Admin.SponsorLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures

  describe "Index" do
    test "lists sponsors with name, url and years", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      media = ContentFixtures.media_fixture(caption: "Test Sponsor Logo")

      Content.attach_media_to_entity(biennale, media,
        metadata: %{
          "role" => "sponsor",
          "name" => "VisitGreece",
          "url" => "https://visitgreece.gr"
        }
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

  describe "add sponsor" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      {:ok, biennale: biennale}
    end

    defp upload_logo(lv) do
      file =
        file_input(lv, "#sponsor-modal form", :sponsor_logo, [
          %{
            name: "logo.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "logo.jpg")
    end

    test "validate stores the typed name in the form", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")

      lv
      |> element("#sponsor-modal form")
      |> render_change(%{"sponsor_name" => "Typed Name"})

      assert render(lv) =~ "Typed Name"
    end

    test "rejects an empty name", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")
      upload_logo(lv)

      html =
        lv
        |> form("#sponsor-modal form", %{"sponsor_name" => " ", "biennale_#{b.id}" => "true"})
        |> render_submit()

      assert html =~ "Enter a sponsor name"
    end

    test "rejects a submit without a logo", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")

      html =
        lv
        |> form("#sponsor-modal form", %{
          "sponsor_name" => "No Logo",
          "biennale_#{b.id}" => "true"
        })
        |> render_submit()

      assert html =~ "Upload a sponsor logo"
    end

    test "rejects a submit with no biennale selected", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")
      upload_logo(lv)

      html =
        lv
        |> form("#sponsor-modal form", %{"sponsor_name" => "Nobody"})
        |> render_submit()

      assert html =~ "Select at least one biennale"
    end

    test "adds a sponsor with a logo and url to the selected biennale", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")
      upload_logo(lv)

      lv
      |> form("#sponsor-modal form", %{
        "sponsor_name" => "New Sponsor",
        "sponsor_url" => "https://new.example",
        "biennale_#{b.id}" => "true"
      })
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      html = render(lv)
      assert html =~ "New Sponsor"
      assert html =~ "https://new.example"
    end

    test "adds a sponsor without a url", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")
      upload_logo(lv)

      lv
      |> form("#sponsor-modal form", %{"sponsor_name" => "Plain", "biennale_#{b.id}" => "true"})
      |> render_submit()

      assert render(lv) =~ "Plain"
    end
  end

  describe "edit, remove and delete" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      other = ContentFixtures.biennale_fixture(year: 2024)
      media = ContentFixtures.media_fixture(caption: "Logo")

      Content.attach_media_to_entity(biennale, media,
        metadata: %{"role" => "sponsor", "name" => "Acme", "url" => "https://acme.example"}
      )

      {:ok, biennale: biennale, other: other, media: media}
    end

    test "edit without a new logo updates name and url", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      lv
      |> form("#sponsor-edit-modal form", %{
        "sponsor_name" => "Acme Renamed",
        "sponsor_url" => "https://renamed.example"
      })
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      html = render(lv)
      assert html =~ "Acme Renamed"
      assert html =~ "https://renamed.example"
    end

    test "edit rejects an empty name", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      html =
        lv
        |> form("#sponsor-edit-modal form", %{"sponsor_name" => "  "})
        |> render_submit()

      assert html =~ "Enter a sponsor name"
    end

    test "edit with a new logo and an extra biennale adds it", %{
      conn: conn,
      other: other
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      file =
        file_input(lv, "#sponsor-edit-modal form", :sponsor_logo, [
          %{
            name: "new.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "new.jpg")

      lv
      |> form("#sponsor-edit-modal form", %{
        "sponsor_name" => "Acme",
        "biennale_#{other.id}" => "true"
      })
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      assert render(lv) =~ "Sponsor updated"
    end

    test "update_sponsor without a selected sponsor reports not found", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html = render_hook(lv, "update_sponsor", %{"sponsor_name" => "Nope"})
      assert html =~ "Sponsor not found"
    end

    test "remove_year drops the sponsorship for one biennale", %{
      conn: conn,
      biennale: b,
      media: m
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html =
        render_hook(lv, "remove_year", %{
          "entity-id" => to_string(b.id),
          "media-id" => to_string(m.id)
        })

      assert html =~ "Sponsorship removed"
    end

    test "remove_year ignores unknown ids", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html =
        render_hook(lv, "remove_year", %{"entity-id" => "999999", "media-id" => "999999"})

      assert html =~ "Sponsorship removed"
    end

    test "delete removes the sponsor everywhere", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")
      html = render_hook(lv, "delete", %{"name" => "Acme"})
      assert html =~ "Sponsor deleted"
      refute html =~ "https://acme.example"
    end

    test "delete with an unknown name still succeeds", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")
      assert render_hook(lv, "delete", %{"name" => "Missing"}) =~ "Sponsor deleted"
    end
  end
end
