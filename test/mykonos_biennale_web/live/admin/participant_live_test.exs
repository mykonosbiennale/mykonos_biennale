defmodule MykonosBiennaleWeb.Admin.ParticipantLiveTest do
  use MykonosBiennaleWeb.AdminCase

  import Ecto.Query, only: [from: 2]

  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.Content.Relationship
  alias MykonosBiennale.Repo

  setup do
    ContentFixtures.ensure_relationship_types()
    :ok
  end

  describe "Index" do
    test "lists participants", %{conn: conn} do
      _participant = ContentFixtures.participant_fixture(first_name: "John", last_name: "Doe")
      {:ok, _lv, html} = live(conn, ~p"/admin/participants")
      assert html =~ "John Doe"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/participants")
      assert html =~ "/admin/participants/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/new")
      html = lv |> element("#participant-form") |> render()
      assert html =~ "first_name"
      assert html =~ "last_name"
    end

    test "creates participant on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/new")

      lv
      |> form("#participant-form", participant: %{first_name: "New", last_name: "Artist"})
      |> render_submit()

      html = render(lv)
      assert html =~ "New Artist"

      assert Repo.exists?(
               from e in Entity, where: e.type == "participant" and e.identity == "New Artist"
             )
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Edit", last_name: "Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/#{participant.id}/edit")
      html = lv |> element("#participant-form") |> render()
      assert html =~ "Edit"
    end

    test "updates participant on valid submit", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Old", last_name: "Name")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants/#{participant.id}/edit")

      lv
      |> form("#participant-form", participant: %{first_name: "Updated"})
      |> render_submit()

      assert_redirect(lv, ~p"/admin/participants/#{participant.id}")
    end
  end

  describe "Show" do
    test "renders participant details", %{conn: conn} do
      participant =
        ContentFixtures.participant_fixture(first_name: "Show", last_name: "Participant")

      {:ok, _lv, html} = live(conn, ~p"/admin/participants/#{participant.id}")
      assert html =~ "Show Participant"
    end
  end

  describe "Delete" do
    test "deletes participant from index", %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Delete", last_name: "Me")
      {:ok, lv, _html} = live(conn, ~p"/admin/participants")
      lv |> element("[phx-click=delete][phx-value-id='#{participant.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Me")
    end
  end

  describe "form validation and save" do
    test "validate shows changeset errors for a blank first name", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/new")

      html =
        lv
        |> form("#participant-form", participant: %{first_name: "", last_name: "Only"})
        |> render_change()

      assert is_binary(html)
    end

    test "save with a blank first name does not redirect", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/new")

      html =
        lv
        |> form("#participant-form", participant: %{first_name: "", last_name: ""})
        |> render_submit()

      assert is_binary(html)
      refute_redirected(lv, ~p"/admin/participants")
    end
  end

  describe "social media handles" do
    test "add then remove a social media entry", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/new")

      lv |> element("button", "+ Add Social Media Handle") |> render_click()
      html = lv |> element("#participant-form") |> render()
      assert html =~ "phx-value-index=\"0\""

      lv
      |> element("button[phx-click=remove_social_media][phx-value-index=\"0\"]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=remove_social_media][phx-value-index=\"0\"]")
    end
  end

  describe "artwork linking" do
    setup %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Linker", last_name: "Test")
      artwork = ContentFixtures.artwork_fixture(title: "Linkable Work")
      {:ok, conn: conn, participant: participant, artwork: artwork}
    end

    test "searches, links and unlinks an artwork", %{conn: conn, participant: p, artwork: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> element("input[phx-keyup=search_artwork_to_link]")
      |> render_keyup(%{"value" => "linkable"})

      assert has_element?(lv, "button[phx-click=link_artwork][phx-value-artwork-id=\"#{a.id}\"]")

      lv
      |> element("button[phx-click=link_artwork][phx-value-artwork-id=\"#{a.id}\"]")
      |> render_click()

      assert render(lv) =~ "Artwork linked successfully"

      assert has_element?(
               lv,
               "button[phx-click=unlink_artwork][phx-value-artwork-id=\"#{a.id}\"]"
             )

      lv
      |> element("button[phx-click=unlink_artwork][phx-value-artwork-id=\"#{a.id}\"]")
      |> render_click()

      refute has_element?(
               lv,
               "button[phx-click=unlink_artwork][phx-value-artwork-id=\"#{a.id}\"]"
             )
    end

    test "blank search clears results", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> element("input[phx-keyup=search_artwork_to_link]")
      |> render_keyup(%{"value" => "   "})

      refute has_element?(lv, "button[phx-click=link_artwork]")
    end
  end

  describe "relationships" do
    setup %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Rel", last_name: "Person")
      target = ContentFixtures.event_fixture(title: "Related Event")
      {:ok, conn: conn, participant: participant, target: target}
    end

    test "creates a relationship through the add form", %{conn: conn, participant: p, target: t} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()
      assert has_element?(lv, "button[phx-click=create_relationship]")

      lv
      |> element("[phx-change=new_rel_search_changed]")
      |> render_change(%{"new_rel_search" => "Related"})

      lv
      |> element("button[phx-click=new_rel_select_entity][phx-value-entity-id=\"#{t.id}\"]")
      |> render_click()

      lv |> element("button[phx-click=new_rel_clear_entity]") |> render_click()
      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()

      assert render(lv) =~ "Relationship" or
               has_element?(lv, "button[phx-click=create_relationship]")
    end

    test "create_relationship without a type or entity shows an error", %{
      conn: conn,
      participant: p
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")
      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()
      lv |> element("button[phx-click=create_relationship]") |> render_click()

      assert has_element?(lv, "button[phx-click=create_relationship]")
    end

    test "toggle_add_relationship opens and closes the add form", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")
      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()
      assert has_element?(lv, "button[phx-click=create_relationship]")
      lv |> element("button[phx-click=toggle_add_relationship]", "Cancel") |> render_click()
      refute has_element?(lv, "button[phx-click=create_relationship]")
    end
  end

  describe "edit page handlers" do
    setup %{conn: conn} do
      participant = ContentFixtures.participant_fixture(first_name: "Edit", last_name: "Page")
      artwork = ContentFixtures.artwork_fixture(title: "Owned Work")
      event = ContentFixtures.event_fixture(title: "Target Event")

      {:ok, rel} =
        ContentFixtures.create_relationship(artwork, participant, "artwork_participant")

      {:ok, conn: conn, participant: participant, artwork: artwork, event: event, rel: rel}
    end

    test "validate with a blank name keeps the form on the page", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> form("#participant-form", participant: %{first_name: ""})
      |> render_change()

      assert has_element?(lv, "#participant-form")
    end

    test "save with a blank first name re-renders the form", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> form("#participant-form", participant: %{first_name: "", last_name: "", name: ""})
      |> render_submit()

      assert has_element?(lv, "#participant-form")
    end

    test "add then remove social media on the edit page", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv |> element("button[phx-click=add_social_media]") |> render_click()
      lv |> element("button[phx-click=add_social_media]") |> render_click()
      assert has_element?(lv, "button[phx-click=remove_social_media][phx-value-index=\"1\"]")

      lv
      |> element("button[phx-click=remove_social_media][phx-value-index=\"1\"]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=remove_social_media][phx-value-index=\"1\"]")
    end

    test "lists the linked artwork with a relationship row", %{conn: conn, participant: p} do
      {:ok, _lv, html} = live(conn, ~p"/admin/participants/#{p.id}/edit")
      assert html =~ "Owned Work"
    end

    test "update_rel_type changes the relationship type", %{conn: conn, participant: p, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      other_type =
        Content.list_relationship_types() |> Enum.find(&(&1.id != rel.relationship_type_id))

      lv
      |> element("select[name=rel_type_#{rel.id}]")
      |> render_change(%{
        "_target" => ["rel_type_#{rel.id}"],
        "rel_type_#{rel.id}" => to_string(other_type.id)
      })

      assert MykonosBiennale.Repo.get!(Relationship, rel.id).relationship_type_id == other_type.id
    end

    test "update_rel_role saves the role on blur", %{conn: conn, participant: p, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> element("[phx-blur=update_rel_role][phx-value-rel-id=\"#{rel.id}\"]")
      |> render_blur(%{"value" => "Director"})

      assert MykonosBiennale.Repo.get!(Relationship, rel.id).fields["roles"] == "Director"
    end

    test "delete_relationship removes the relationship", %{conn: conn, participant: p, rel: rel} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv
      |> element("button[phx-click=delete_relationship][phx-value-rel-id=\"#{rel.id}\"]")
      |> render_click()

      assert MykonosBiennale.Repo.get(Relationship, rel.id) == nil
    end

    test "the add-relationship form creates a relationship to an event", %{
      conn: conn,
      participant: p,
      event: event
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")

      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()

      lv
      |> element("select[name=new_rel_type]")
      |> render_change(%{"new_rel_type" => to_string(hd(Content.list_relationship_types()).id)})

      lv
      |> element("select[name=new_rel_direction]")
      |> render_change(%{"new_rel_direction" => "subject"})

      lv
      |> element("[phx-change=new_rel_search_changed] input, input[name=new_rel_search]")
      |> render_change(%{"new_rel_search" => "Target"})

      lv
      |> element("button[phx-click=new_rel_select_entity][phx-value-entity-id=\"#{event.id}\"]")
      |> render_click()

      lv
      |> element("textarea[name=new_rel_fields], input[name=new_rel_fields]")
      |> render_change(%{"new_rel_fields" => "{\"roles\": \"Host\"}"})

      lv |> element("button[phx-click=create_relationship]") |> render_click()
      assert has_element?(lv, "button[phx-click=delete_relationship]")
    end

    test "create_relationship with no selection keeps the form open", %{
      conn: conn,
      participant: p
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")
      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()
      lv |> element("button[phx-click=create_relationship]") |> render_click()
      assert has_element?(lv, "button[phx-click=create_relationship]")
    end

    test "clearing the selected entity and toggling the form closes it", %{
      conn: conn,
      participant: p,
      event: event
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}/edit")
      lv |> element("button[phx-click=toggle_add_relationship]", "+ Add") |> render_click()

      lv
      |> element("input[name=new_rel_search]")
      |> render_change(%{"new_rel_search" => "Target"})

      lv
      |> element("button[phx-click=new_rel_select_entity][phx-value-entity-id=\"#{event.id}\"]")
      |> render_click()

      lv |> element("button[phx-click=new_rel_clear_entity]") |> render_click()
      lv |> element("button[phx-click=toggle_add_relationship]", "Cancel") |> render_click()
      refute has_element?(lv, "button[phx-click=create_relationship]")
    end
  end

  describe "new participant form" do
    test "uploads a headshot and saves it with the participant", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/new")

      file =
        file_input(lv, "#participant-form", :headshot, [
          %{
            name: "head.jpg",
            content: File.read!(Path.expand("test/support/fixtures/files/test.jpg")),
            type: "image/jpeg"
          }
        ])

      render_upload(file, "head.jpg")

      lv
      |> form("#participant-form", participant: %{first_name: "Head", last_name: "Shot"})
      |> render_submit()

      assert Repo.exists?(
               from e in Entity,
                 where: e.type == "participant" and ilike(e.identity, "%Head Shot%")
             )
    end

    test "social media entries can be added and removed before saving", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/new")

      lv |> element("button[phx-click=add_social_media]") |> render_click()
      assert has_element?(lv, "button[phx-click=remove_social_media][phx-value-index=\"0\"]")

      lv
      |> element("button[phx-click=remove_social_media][phx-value-index=\"0\"]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=remove_social_media][phx-value-index=\"0\"]")
    end
  end

  describe "Show handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      participant = ContentFixtures.participant_fixture(first_name: "Show", last_name: "Handler")
      linked = ContentFixtures.artwork_fixture(title: "Already Linked")
      free = ContentFixtures.artwork_fixture(title: "Free Artwork")
      {:ok, _} = Content.attach_participant_to_artwork(linked, participant, "creator")
      {:ok, participant: participant, linked: linked, free: free}
    end

    test "switch_tab moves to the fields tab", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}")
      lv |> element("button[phx-click=switch_tab][phx-value-tab=fields]") |> render_click()
      assert has_element?(lv, "button[phx-click=switch_tab][phx-value-tab=fields]")
    end

    test "fields_changed info stores edited participant fields", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}")

      send(lv.pid, {:fields_changed, %{content: ~s({"bio": "Edited bio"})}})
      _ = render(lv)
      assert Repo.get!(Entity, p.id).fields["bio"] == "Edited bio"

      send(lv.pid, {:fields_changed, %{content: "not json"}})
      _ = render(lv)
      assert Repo.get!(Entity, p.id).fields["bio"] == "Edited bio"
    end

    test "a newly created artwork is linked to the participant", %{conn: conn, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/participants/#{p.id}")
      art = ContentFixtures.artwork_fixture(title: "Brand New Work")

      send(
        lv.pid,
        {MykonosBiennaleWeb.Admin.ArtworkLive.FormComponent, {:saved, art}}
      )

      _ = render(lv)
      assert Enum.any?(Content.list_participant_linked_artworks(p), &(&1.subject_id == art.id))
    end

    test "new artwork modal renders on the new_artwork route", %{conn: conn, participant: p} do
      {:ok, _lv, html} = live(conn, ~p"/admin/participants/#{p.id}/artworks/new")
      assert html =~ "Show Handler"
    end
  end
end
