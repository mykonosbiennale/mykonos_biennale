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
end
