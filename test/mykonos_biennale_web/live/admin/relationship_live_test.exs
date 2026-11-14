defmodule MykonosBiennaleWeb.Admin.RelationshipLiveTest do
  use MykonosBiennaleWeb.AdminCase

  describe "Index" do
    test "lists relationships", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Rel Artwork")
      participant = ContentFixtures.participant_fixture(first_name: "Rel", last_name: "Artist")
      ContentFixtures.link_artwork_to_participant(artwork, participant)

      {:ok, _lv, html} = live(conn, ~p"/admin/relationships")
      assert html =~ "artwork_participant"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/relationships")
      assert html =~ "/admin/relationships/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/relationships/new")
      html = lv |> element("#relationship-form") |> render()
      assert html =~ "relationship_type_id"
      assert html =~ "subject_id"
      assert html =~ "object_id"
    end
  end

  describe "Show" do
    test "renders relationship details", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Show Rel Artwork")
      participant = ContentFixtures.participant_fixture(first_name: "Show", last_name: "Rel")
      {:ok, rel} = ContentFixtures.link_artwork_to_participant(artwork, participant)

      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "artwork_participant"
    end

    test "renders relationship fields in show", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Fields Show Artwork")
      participant = ContentFixtures.participant_fixture(first_name: "Fields", last_name: "Show")

      {:ok, rel} =
        ContentFixtures.link_artwork_to_participant(artwork, participant,
          fields: %{"roles" => "Director"}
        )

      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "roles"
      assert html =~ "Director"
    end
  end

  describe "Delete" do
    test "deletes relationship from index", %{conn: conn} do
      artwork = ContentFixtures.artwork_fixture(title: "Del Rel Artwork")
      participant = ContentFixtures.participant_fixture(first_name: "Del", last_name: "Rel")
      {:ok, rel} = ContentFixtures.link_artwork_to_participant(artwork, participant)

      {:ok, lv, _html} = live(conn, ~p"/admin/relationships")
      lv |> element("[phx-click=delete][phx-value-id='#{rel.id}']") |> render_click()
    end
  end

  describe "Form and show handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025)
      participant = ContentFixtures.participant_fixture(first_name: "Rel", last_name: "Subject")
      rt = hd(MykonosBiennale.Content.list_relationship_types())
      {:ok, biennale: biennale, participant: participant, rt: rt}
    end

    test "creating a relationship with all fields saves it", %{
      conn: conn,
      biennale: b,
      participant: p,
      rt: rt
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships/new")

      lv
      |> form("#relationship-form",
        relationship: %{
          relationship_type_id: to_string(rt.id),
          subject_id: to_string(p.id),
          object_id: to_string(b.id),
          fields: "{}"
        }
      )
      |> render_submit()

      assert MykonosBiennale.Repo.get_by(MykonosBiennale.Content.Relationship,
               subject_id: p.id,
               object_id: b.id
             )
    end

    test "validate re-renders the form on a change", %{conn: conn, participant: p, rt: rt} do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships/new")

      lv
      |> form("#relationship-form",
        relationship: %{relationship_type_id: to_string(rt.id), subject_id: to_string(p.id)}
      )
      |> render_change()

      assert has_element?(lv, "#relationship-form")
    end

    test "creating without a type keeps the form open", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships/new")

      lv
      |> form("#relationship-form",
        relationship: %{subject_id: to_string(p.id), relationship_type_id: ""}
      )
      |> render_submit()

      assert has_element?(lv, "#relationship-form")
    end

    test "editing a relationship saves the changed fields", %{
      conn: conn,
      biennale: b,
      participant: p
    } do
      {:ok, rel} = ContentFixtures.create_relationship(p, b, "biennale_participant")
      {:ok, lv, _} = live(conn, ~p"/admin/relationships/#{rel.id}/edit")

      lv
      |> form("#relationship-form", relationship: %{fields: ~s({"role": "Guest"})})
      |> render_submit()

      assert MykonosBiennale.Repo.get!(MykonosBiennale.Content.Relationship, rel.id).fields[
               "role"
             ] == "Guest"
    end

    test "delete on the show page removes the relationship and navigates to the index", %{
      conn: conn,
      biennale: b,
      participant: p
    } do
      {:ok, rel} = ContentFixtures.create_relationship(p, b, "biennale_participant")
      {:ok, lv, _} = live(conn, ~p"/admin/relationships/#{rel.id}")

      lv |> element("button[phx-click=delete]") |> render_click()

      assert_redirect(lv, "/admin/relationships")
      assert MykonosBiennale.Repo.get(MykonosBiennale.Content.Relationship, rel.id) == nil
    end
  end

  describe "Show labels and links" do
    setup do
      ContentFixtures.ensure_relationship_types()
      event = ContentFixtures.event_fixture(title: "Linked Event Show")
      project = ContentFixtures.project_fixture(title: "Linked Project Show")
      film = ContentFixtures.film_fixture(title: "Linked Film Show")
      {:ok, event: event, project: project, film: film}
    end

    defp blank_identity(entity) do
      entity
      |> Ecto.Changeset.change(identity: "")
      |> MykonosBiennale.Repo.update!()
    end

    test "an event on one side links to the event page", %{conn: conn, event: e, project: p} do
      {:ok, rel} = ContentFixtures.create_relationship(e, p, "event_project")
      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "/admin/events/#{e.id}"
      assert html =~ "/admin/projects/#{p.id}"
    end

    test "a film on one side links to the film page", %{conn: conn, film: f, project: p} do
      {:ok, rel} = ContentFixtures.create_relationship(f, p, "event_project")
      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "/admin/films/#{f.id}"
    end

    test "a blank identity falls back to the name field", %{conn: conn, project: p} do
      named =
        ContentFixtures.participant_fixture(first_name: "Ignored", last_name: "Ignored")
        |> blank_identity()
        |> Ecto.Changeset.change(fields: %{"name" => "Fallback Name"})
        |> MykonosBiennale.Repo.update!()

      {:ok, rel} = ContentFixtures.create_relationship(named, p, "event_project")
      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "Fallback Name"
    end

    test "a blank identity falls back to first and last name", %{conn: conn, project: p} do
      person =
        ContentFixtures.participant_fixture(first_name: "Ada", last_name: "Lovelace")
        |> blank_identity()

      {:ok, rel} = ContentFixtures.create_relationship(person, p, "event_project")
      {:ok, _lv, html} = live(conn, ~p"/admin/relationships/#{rel.id}")
      assert html =~ "Ada Lovelace"
    end
  end

  describe "Index search and saved" do
    setup do
      ContentFixtures.ensure_relationship_types()
      biennale = ContentFixtures.biennale_fixture(year: 2025, theme: "Index Search Theme")
      person = ContentFixtures.participant_fixture(first_name: "Searched", last_name: "Person")
      {:ok, _} = ContentFixtures.create_relationship(person, biennale, "biennale_participant")
      other = ContentFixtures.participant_fixture(first_name: "Unrelated", last_name: "Thing")
      {:ok, _} = ContentFixtures.create_relationship(other, biennale, "biennale_team")
      {:ok, biennale: biennale}
    end

    test "search narrows the relationship list", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships")
      html = render_hook(lv, "search", %{"search" => "biennale_participant"})
      assert html =~ "biennale_participant"
      refute html =~ "biennale_team"
    end

    test "clear_search restores the list and patches the URL", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships")
      render_hook(lv, "search", %{"search" => "zzz-nothing"})
      render_hook(lv, "clear_search", %{})
      assert_patch(lv, "/admin/relationships?sort_by=inserted_at&page=1&sort_dir=desc")
      assert render(lv) =~ "biennale_team"
    end

    test "a saved relationship from the form is shown in the list", %{conn: conn, biennale: b} do
      {:ok, lv, _} = live(conn, ~p"/admin/relationships")
      person = ContentFixtures.participant_fixture(first_name: "Fresh", last_name: "Link")
      {:ok, rel} = ContentFixtures.create_relationship(person, b, "directed")

      send(lv.pid, {MykonosBiennaleWeb.Admin.RelationshipLive.FormComponent, {:saved, rel}})
      assert render(lv) =~ "directed"
    end
  end
end
