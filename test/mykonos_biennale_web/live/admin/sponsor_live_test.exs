defmodule MykonosBiennaleWeb.Admin.SponsorLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures
  alias MykonosBiennale.Sponsors

  defp sponsor_named(name, biennales, opts \\ []) do
    {:ok, sponsor} = Sponsors.save(name, opts[:url] || "", logo: opts[:logo])
    Enum.each(biennales, &Sponsors.link(sponsor.id, &1.id))
    sponsor
  end

  defp find_sponsor(name), do: Enum.find(Sponsors.list_sponsors(), &(&1.name == name))

  defp upload_logo(lv, form_selector) do
    file =
      file_input(lv, form_selector, :sponsor_logo, [
        %{
          name: "logo.jpg",
          content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
          type: "image/jpeg"
        }
      ])

    render_upload(file, "logo.jpg")
  end

  describe "Index" do
    test "lists sponsors with name, url and years", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      sponsor_named("VisitGreece", [biennale], url: "https://visitgreece.gr")

      {:ok, _lv, html} = live(conn, ~p"/admin/sponsors")
      assert html =~ "VisitGreece"
      assert html =~ "https://visitgreece.gr"
      assert html =~ "2025"
    end

    test "one sponsor supporting two biennales is listed once with both years", %{conn: conn} do
      b2013 = ContentFixtures.biennale_fixture(year: 2013)
      b2015 = ContentFixtures.biennale_fixture(year: 2015)
      sponsor_named("SEAJETS", [b2013, b2015])

      {:ok, _lv, html} = live(conn, ~p"/admin/sponsors")
      assert html |> String.split(~s(phx-value-name="SEAJETS")) |> length() == 2
      assert html =~ "2013"
      assert html =~ "2015"
    end

    test "shows a sponsor that has no logo", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2019)
      sponsor_named("No Logo Co", [biennale])

      {:ok, _lv, html} = live(conn, ~p"/admin/sponsors")
      assert html =~ "No Logo Co"
      assert html =~ "Logo missing"
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

    test "edit form pre-ticks the biennales the sponsor already supports", %{conn: conn} do
      b2025 = ContentFixtures.biennale_fixture(year: 2025)
      _b2024 = ContentFixtures.biennale_fixture(year: 2024)
      sponsor_named("EditMe", [b2025], url: "https://example.com")

      {:ok, lv, _html} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("EditMe")}/edit")
      html = lv |> element("#sponsor-edit-modal") |> render()
      assert html =~ "Edit Sponsor"
      assert html =~ "EditMe"
      assert html =~ "Click to upload or drag and drop"
      assert html =~ "2025"
      assert html =~ "2024"
      assert html =~ ~s(name="biennale_#{b2025.id}")
      assert html =~ "checked"
    end
  end

  describe "add sponsor" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      {:ok, biennale: biennale}
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

      html =
        lv
        |> form("#sponsor-modal form", %{"sponsor_name" => " ", "biennale_#{b.id}" => "true"})
        |> render_submit()

      assert html =~ "Enter a sponsor name"
    end

    test "rejects a submit with no biennale selected", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")

      html =
        lv
        |> form("#sponsor-modal form", %{"sponsor_name" => "Nobody"})
        |> render_submit()

      assert html =~ "Select at least one biennale"
    end

    test "adds a sponsor with a logo and url to the selected biennale", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")
      upload_logo(lv, "#sponsor-modal form")

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
      assert %{logo: logo, years: ["2025"]} = find_sponsor("New Sponsor")
      assert logo
    end

    test "adds a sponsor without a logo", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/new")

      lv
      |> form("#sponsor-modal form", %{"sponsor_name" => "Plain", "biennale_#{b.id}" => "true"})
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      assert render(lv) =~ "Plain"
      assert %{logo: nil, years: ["2025"]} = find_sponsor("Plain")
    end
  end

  describe "edit, remove and delete" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      other = ContentFixtures.biennale_fixture(year: 2024)
      media = ContentFixtures.media_fixture(caption: "Logo")

      sponsor_named("Acme", [biennale], url: "https://acme.example", logo: media)

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

    test "edit rejects a name that another sponsor already has", %{conn: conn} do
      sponsor_named("Taken", [])

      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      html =
        lv
        |> form("#sponsor-edit-modal form", %{"sponsor_name" => "Taken"})
        |> render_submit()

      assert html =~ "Another sponsor already has that name"
    end

    test "ticking an extra biennale adds the support link", %{conn: conn, other: other} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      lv
      |> form("#sponsor-edit-modal form", %{
        "sponsor_name" => "Acme",
        "biennale_#{other.id}" => "true"
      })
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      assert render(lv) =~ "Sponsor updated — added to 1 more biennale(s)"
      assert Enum.sort(find_sponsor("Acme").years) == ["2024", "2025"]
    end

    test "saving keeps existing support links (they are removed from the list)", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")

      lv
      |> form("#sponsor-edit-modal form", %{"sponsor_name" => "Acme"})
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      assert find_sponsor("Acme").years == ["2025"]
    end

    test "edit with a new logo replaces the logo", %{conn: conn, other: other} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors/#{URI.encode_www_form("Acme")}/edit")
      upload_logo(lv, "#sponsor-edit-modal form")

      lv
      |> form("#sponsor-edit-modal form", %{
        "sponsor_name" => "Acme",
        "biennale_#{other.id}" => "true"
      })
      |> render_submit()

      assert_patch(lv, "/admin/sponsors")
      assert render(lv) =~ "Sponsor updated"
      assert find_sponsor("Acme").logo
    end

    test "update_sponsor without a selected sponsor reports not found", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html = render_hook(lv, "update_sponsor", %{"sponsor_name" => "Nope"})
      assert html =~ "Sponsor not found"
    end

    test "remove_year drops the sponsorship for one biennale", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")
      acme = find_sponsor("Acme")
      [%{id: biennale_id}] = acme.biennales

      html =
        render_hook(lv, "remove_year", %{
          "entity-id" => to_string(acme.id),
          "biennale-id" => to_string(biennale_id)
        })

      assert html =~ "Sponsorship removed"
      assert find_sponsor("Acme").years == []
    end

    test "remove_year ignores unknown ids", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html =
        render_hook(lv, "remove_year", %{"entity-id" => "999999", "biennale-id" => "999998"})

      assert html =~ "Sponsorship removed"
    end

    test "delete removes the sponsor everywhere", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")

      html = render_hook(lv, "delete", %{"name" => "Acme"})
      assert html =~ "Sponsor deleted"
      refute html =~ "https://acme.example"
      assert find_sponsor("Acme") == nil
    end

    test "delete with an unknown name still succeeds", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/sponsors")
      refute render_hook(lv, "delete", %{"name" => "Missing"}) =~ "Sponsor deleted"
    end
  end
end
