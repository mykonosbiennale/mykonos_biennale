defmodule MykonosBiennaleWeb.Admin.TeamLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures

  describe "Index" do
    test "lists team members grouped by participant with biennale years and roles", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      participant = ContentFixtures.participant_fixture(first_name: "Team", last_name: "Member")

      ContentFixtures.create_relationship(biennale, participant, "biennale_team", %{
        "role" => "curator"
      })

      {:ok, _lv, html} = live(conn, ~p"/admin/teams")
      assert html =~ "Team Member"
      assert html =~ "2025"
      assert html =~ "curator"
    end

    test "shows empty state when no team members", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/teams")
      assert html =~ "No team members yet"
    end

    test "renders add team member form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/teams/new")
      html = lv |> element("#team-member-modal") |> render()
      assert html =~ "Add Team Member"
      assert html =~ "Select role..."
    end
  end

  describe "Member page /admin/teams/:id" do
    test "shows readonly memberships table with year, role, image, and actions", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)

      participant =
        ContentFixtures.participant_fixture(first_name: "Kimona", last_name: "Venieri")

      ContentFixtures.create_relationship(biennale, participant, "biennale_team", %{
        "role" => "curator"
      })

      {:ok, _lv, html} = live(conn, ~p"/admin/teams/#{participant.id}")
      assert html =~ "Kimona Venieri"
      assert html =~ "2025"
      assert html =~ "Curator"
      assert html =~ "headshot (default)"
      assert html =~ "Edit"
      assert html =~ "Remove"
      refute html =~ "Upload image (jpg"
    end

    test "edit modal shows year, role select, and image upload", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      participant = ContentFixtures.participant_fixture(first_name: "Modal", last_name: "Editor")

      {:ok, _rel} =
        ContentFixtures.create_relationship(biennale, participant, "biennale_team", %{
          "role" => "curator"
        })

      {:ok, lv, _html} = live(conn, ~p"/admin/teams/#{participant.id}")

      lv
      |> element("button", "Edit")
      |> render_click()

      html = lv |> element("#membership-edit-modal") |> render()
      assert html =~ "Modal Editor — 2025"
      assert html =~ "Upload image (jpg, gif, png, webp)"
      assert html =~ "Save"
      assert html =~ "Remove membership"
    end

    test "shows custom image in list and edit modal offers Use headshot", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      participant = ContentFixtures.participant_fixture(first_name: "Custom", last_name: "Imager")
      media = ContentFixtures.media_fixture(caption: "Custom Team Image")

      ContentFixtures.create_relationship(biennale, participant, "biennale_team", %{
        "role" => "curator",
        "image_media_id" => media.id
      })

      {:ok, lv, html} = live(conn, ~p"/admin/teams/#{participant.id}")
      assert html =~ "custom"

      lv
      |> element("button", "Edit")
      |> render_click()

      modal_html = lv |> element("#membership-edit-modal") |> render()
      assert modal_html =~ "current custom image"
      assert modal_html =~ "Use headshot"
    end
  end
end
