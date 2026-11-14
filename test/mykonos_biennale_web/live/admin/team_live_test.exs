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

  describe "Index handlers" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      other = ContentFixtures.biennale_fixture(year: 2024)
      member = ContentFixtures.participant_fixture(first_name: "Member", last_name: "One")
      candidate = ContentFixtures.participant_fixture(first_name: "Candidate", last_name: "Two")

      {:ok, rel} =
        ContentFixtures.create_relationship(biennale, member, "biennale_team", %{
          "role" => "curator"
        })

      {:ok, biennale: biennale, other: other, member: member, candidate: candidate, rel: rel}
    end

    test "search_participants lists matching participants not yet on the team", %{
      conn: conn,
      candidate: c
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")

      html =
        render_hook(lv, "search_participants", %{
          "participant_search" => "candidate",
          "_target" => ["participant_search"]
        })

      assert html =~ "Candidate Two"

      assert has_element?(
               lv,
               "button[phx-click=select_participant][phx-value-participant-id=\"#{c.id}\"]"
             )
    end

    test "a blank search clears the results", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")

      html =
        render_hook(lv, "search_participants", %{
          "participant_search" => "   ",
          "_target" => ["participant_search"]
        })

      refute html =~ "select_participant"
    end

    test "select and clear a participant", %{conn: conn, candidate: c} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")

      render_hook(lv, "select_participant", %{"participant-id" => to_string(c.id)})
      assert render(lv) =~ "Candidate"

      render_hook(lv, "clear_participant", %{})
      refute has_element?(lv, "button[phx-click=clear_participant]")
    end

    test "add_team_member without a participant reports the error", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")

      html =
        render_hook(lv, "add_team_member", %{
          "role" => "curator",
          "biennale_#{b.id}" => "true"
        })

      assert html =~ "Select a participant"
    end

    test "add_team_member without a role reports the error", %{
      conn: conn,
      candidate: c,
      biennale: b
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")
      render_hook(lv, "select_participant", %{"participant-id" => to_string(c.id)})

      html = render_hook(lv, "add_team_member", %{"role" => "", "biennale_#{b.id}" => "true"})
      assert html =~ "Select a role"
    end

    test "add_team_member without a biennale reports the error", %{conn: conn, candidate: c} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")
      render_hook(lv, "select_participant", %{"participant-id" => to_string(c.id)})

      html = render_hook(lv, "add_team_member", %{"role" => "curator"})
      assert html =~ "Select at least one biennale"
    end

    test "add_team_member adds the participant to the chosen biennales", %{
      conn: conn,
      candidate: c,
      biennale: b,
      other: o
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/new")
      render_hook(lv, "select_participant", %{"participant-id" => to_string(c.id)})

      render_hook(lv, "add_team_member", %{
        "role" => "producer",
        "biennale_#{b.id}" => "true",
        "biennale_#{o.id}" => "true"
      })

      assert_patch(lv, "/admin/teams")
      html = render(lv)
      assert html =~ "Candidate Two"
      assert html =~ "producer"
    end

    test "update_role stores a new role on the membership", %{conn: conn, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams")
      render_hook(lv, "update_role", %{"rel-id" => to_string(rel.id), "value" => "designer"})

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Relationship, rel.id).fields[
               "role"
             ] ==
               "designer"
    end

    test "update_role with an unknown membership still reports success", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams")

      assert render_hook(lv, "update_role", %{"rel-id" => "999999", "value" => "x"}) =~
               "Role updated"
    end

    test "remove_membership deletes one membership", %{conn: conn, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams")

      assert render_hook(lv, "remove_membership", %{"rel-id" => to_string(rel.id)}) =~
               "Membership removed"

      assert MykonosBiennale.Repo.get(MykonosBiennale.Content.Relationship, rel.id) == nil
    end

    test "delete removes every membership of a participant", %{conn: conn, member: m, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams")

      assert render_hook(lv, "delete", %{"participant-id" => to_string(m.id)}) =~
               "Team member removed"

      assert MykonosBiennale.Repo.get(MykonosBiennale.Content.Relationship, rel.id) == nil
    end
  end

  describe "Member handlers" do
    setup do
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      participant = ContentFixtures.participant_fixture(first_name: "Member", last_name: "Page")

      {:ok, rel} =
        ContentFixtures.create_relationship(biennale, participant, "biennale_team", %{
          "role" => "curator"
        })

      {:ok, participant: participant, rel: rel}
    end

    test "edit_membership opens and close_edit closes the modal", %{
      conn: conn,
      participant: p,
      rel: rel
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")

      render_hook(lv, "edit_membership", %{"rel-id" => to_string(rel.id)})
      assert has_element?(lv, "#membership-edit-modal")

      render_hook(lv, "close_edit", %{})
      refute has_element?(lv, "#membership-edit-modal")
    end

    test "validate_membership is a no-op", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")
      assert render_hook(lv, "validate_membership", %{}) =~ "Member Page"
    end

    test "save_membership updates the role without an image", %{
      conn: conn,
      participant: p,
      rel: rel
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")

      html =
        render_hook(lv, "save_membership", %{"rel_id" => to_string(rel.id), "role" => "director"})

      assert html =~ "Membership updated"

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Relationship, rel.id).fields[
               "role"
             ] ==
               "director"
    end

    test "save_membership with an uploaded image stores it on the membership", %{
      conn: conn,
      participant: p,
      rel: rel
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")
      render_hook(lv, "edit_membership", %{"rel-id" => to_string(rel.id)})

      file =
        file_input(lv, "#membership-edit-modal form", :image, [
          %{
            name: "team.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "team.jpg")

      render_hook(lv, "save_membership", %{"rel_id" => to_string(rel.id), "role" => "curator"})

      fields = MykonosBiennale.Repo.get!(MykonosBiennale.Content.Relationship, rel.id).fields
      assert is_integer(fields["image_media_id"])
    end

    test "clear_image removes the custom image", %{conn: conn, participant: p, rel: rel} do
      media = ContentFixtures.media_fixture(caption: "Team pic")

      rel
      |> Ecto.Changeset.change(fields: %{"role" => "curator", "image_media_id" => media.id})
      |> MykonosBiennale.Repo.update!()

      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")

      assert render_hook(lv, "clear_image", %{"rel-id" => to_string(rel.id)}) =~
               "Reverted to headshot"

      refute Map.has_key?(
               MykonosBiennale.Repo.get!(MykonosBiennale.Content.Relationship, rel.id).fields,
               "image_media_id"
             )
    end

    test "remove_membership from the member page", %{conn: conn, participant: p, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/teams/#{p.id}")

      assert render_hook(lv, "remove_membership", %{"rel-id" => to_string(rel.id)}) =~
               "Membership removed"

      assert MykonosBiennale.Repo.get(MykonosBiennale.Content.Relationship, rel.id) == nil
    end
  end
end
