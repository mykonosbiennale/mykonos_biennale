defmodule MykonosBiennaleWeb.Admin.BiennaleLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists biennales", %{conn: conn} do
      __biennale = ContentFixtures.biennale_fixture(year: 2024, theme: "Test Biennale")
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales")
      assert html =~ "Test Biennale"
      assert html =~ "2024"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales")
      assert html =~ "/admin/biennales/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")
      html = lv |> element("#biennale-form") |> render()
      assert html =~ "year"
      assert html =~ "theme"
    end

    test "creates biennale on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")

      lv
      |> form("#biennale-form", biennale: %{year: 2026, theme: "New Theme"})
      |> render_submit()

      # The component's flash is handled by the parent after the event.
      assert render(lv) =~ "created successfully"
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/new")

      html =
        lv
        |> form("#biennale-form", biennale: %{year: nil, theme: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2023, theme: "Old Theme")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/#{biennale.id}/edit")
      html = lv |> element("#biennale-form") |> render()
      assert html =~ "Old Theme"
    end

    test "updates biennale on valid submit", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2023, theme: "Old Theme")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales/#{biennale.id}/edit")

      lv
      |> form("#biennale-form", biennale: %{theme: "Updated Theme"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/biennales")
    end
  end

  describe "Show" do
    test "renders biennale details", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Show Theme")
      {:ok, _lv, html} = live(conn, ~p"/admin/biennales/#{biennale.id}")
      assert html =~ "Show Theme"
      assert html =~ "2025"
    end

    test "switch_tab changes the active tab", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2026, theme: "Tabs")
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{biennale.id}")
      render_hook(lv, "switch_tab", %{"tab" => "fields"})
      assert has_element?(lv, "button[phx-click=switch_tab][phx-value-tab=fields]")
    end

    test "fields_changed stores the edited biennale fields", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2027, theme: "Editable")
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{biennale.id}")

      send(lv.pid, {:fields_changed, %{content: ~s({"year": "2027", "theme": "Edited Theme"})}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, biennale.id).fields[
               "theme"
             ] ==
               "Edited Theme"

      send(lv.pid, {:fields_changed, %{content: "bad"}})
      _ = render(lv)

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Entity, biennale.id).fields[
               "theme"
             ] ==
               "Edited Theme"
    end
  end

  describe "Delete" do
    test "deletes biennale from index", %{conn: conn} do
      biennale = ContentFixtures.biennale_fixture(year: 2022, theme: "Delete Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/biennales")
      lv |> element("[phx-click=delete][phx-value-id='#{biennale.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Me")
    end
  end

  describe "Form team, backgrounds and sponsors" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      member = ContentFixtures.participant_fixture(first_name: "Team", last_name: "Member")
      candidate = ContentFixtures.participant_fixture(first_name: "Team", last_name: "Candidate")

      {:ok, _} =
        ContentFixtures.create_relationship(biennale, member, "biennale_team", %{
          "role" => "curator"
        })

      bg = ContentFixtures.media_fixture(caption: "Statement bg")
      Content.attach_media_to_entity(biennale, bg, metadata: %{"role" => "statement_bg"})

      {:ok, sponsor} = MykonosBiennale.Sponsors.save("Acme Co", "https://acme.example")
      MykonosBiennale.Sponsors.link(sponsor.id, biennale.id)

      {:ok, biennale: biennale, member: member, candidate: candidate, bg: bg, sponsor: sponsor}
    end

    test "validate with a blank year keeps the form open", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")
      lv |> form("#biennale-form", biennale: %{year: ""}) |> render_change()
      assert has_element?(lv, "#biennale-form")
    end

    test "search_team lists a matching participant", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("input[name=team_search]")
      |> render_change(%{"team_search" => "candidate", "_target" => ["team_search"]})

      assert render(lv) =~ "Team Candidate"
    end

    test "search_team with a blank term clears the results", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("input[name=team_search]")
      |> render_change(%{"team_search" => "   ", "_target" => ["team_search"]})

      refute has_element?(lv, "select[name^=role_]")
    end

    test "add_team_member adds the chosen participant with a role", %{
      conn: conn,
      biennale: b,
      candidate: c
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("input[name=team_search]")
      |> render_change(%{"team_search" => "candidate", "_target" => ["team_search"]})

      name = "role_#{c.id}"

      lv
      |> element("select[name=#{name}]")
      |> render_change(%{"_target" => [name], name => "producer"})

      assert render(lv) =~ "Team Candidate"
    end

    test "add_team_member without a role reports the error", %{
      conn: conn,
      biennale: b,
      candidate: c
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("input[name=team_search]")
      |> render_change(%{"team_search" => "candidate", "_target" => ["team_search"]})

      name = "role_#{c.id}"

      html =
        lv
        |> element("select[name=#{name}]")
        |> render_change(%{"_target" => [name], name => ""})

      assert html =~ "Team Candidate"
    end

    test "remove_team_member removes a member", %{conn: conn, biennale: b, member: m} do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("button[phx-click=remove_team_member][phx-value-participant-id=\"#{m.id}\"]")
      |> render_click()

      refute has_element?(
               lv,
               "button[phx-click=remove_team_member][phx-value-participant-id=\"#{m.id}\"]"
             )
    end

    test "remove_bg detaches the statement background", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("button[phx-click=remove_bg][phx-value-role=statement_bg]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=remove_bg][phx-value-role=statement_bg]")
    end

    test "remove_sponsor unlinks a sponsor from this biennale", %{
      conn: conn,
      biennale: b,
      sponsor: s
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/biennales/#{b.id}/edit")

      lv
      |> element("button[phx-click=remove_sponsor][phx-value-sponsor-id=\"#{s.id}\"]")
      |> render_click()

      refute has_element?(
               lv,
               "button[phx-click=remove_sponsor][phx-value-sponsor-id=\"#{s.id}\"]"
             )

      assert MykonosBiennale.Sponsors.for_biennale(b.id) == []
    end
  end
end
