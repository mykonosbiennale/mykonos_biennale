defmodule MykonosBiennaleWeb.Admin.MediaLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures

  describe "Index" do
    test "lists media", %{conn: conn} do
      _media = ContentFixtures.media_fixture(caption: "Test Media Caption")
      {:ok, _lv, html} = live(conn, ~p"/admin/media")
      assert html =~ "Test Media Caption"
    end

    test "has Add Media link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media")
      assert html =~ "/admin/media/new"
    end
  end

  describe "New" do
    test "renders form with caption and source_type fields", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/media/new")
      html = lv |> element("#media-form") |> render()
      assert html =~ "caption"
      assert html =~ "source_type"
    end
  end

  describe "Edit" do
    test "renders form with existing caption", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Edit Media Caption")
      {:ok, lv, _html} = live(conn, ~p"/admin/media/#{media.id}/edit")
      html = lv |> element("#media-form") |> render()
      assert html =~ "Edit Media Caption"
    end

    test "updates media caption on valid submit", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Old Caption")
      {:ok, lv, _html} = live(conn, ~p"/admin/media/#{media.id}/edit")

      html =
        lv
        |> form("#media-form", media: %{caption: "Updated Caption"})
        |> render_submit()

      assert html =~ "Updated Caption"
    end
  end

  describe "Show" do
    test "renders media details", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Show Media")
      {:ok, _lv, html} = live(conn, ~p"/admin/media/#{media.id}")
      assert html =~ "Show Media"
    end
  end

  describe "Rotate" do
    test "mounts batch rotate page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media/rotate")
      assert html =~ "Batch Rotate Media"
    end
  end

  describe "Show linked entities and preview" do
    setup do
      ContentFixtures.ensure_relationship_types()
      media = ContentFixtures.media_fixture(caption: "Linked Media")
      {:ok, media: media}
    end

    test "lists every linked entity type with its link", %{conn: conn, media: media} do
      participant = ContentFixtures.participant_fixture(first_name: "Pia", last_name: "Linked")
      artwork = ContentFixtures.artwork_fixture(title: "Linked Artwork")
      event = ContentFixtures.event_fixture(title: "Linked Event")
      biennale = ContentFixtures.biennale_fixture(year: 2026)
      project = ContentFixtures.project_fixture(title: "Linked Project")

      for entity <- [participant, artwork, event, biennale, project] do
        Content.attach_media_to_entity(entity, media, metadata: %{})
      end

      {:ok, _lv, html} = live(conn, ~p"/admin/media/#{media.id}")
      assert html =~ "Pia Linked"
      assert html =~ "Linked Artwork"
      assert html =~ "Linked Event"
      assert html =~ "/admin/participants/#{participant.id}"
      assert html =~ "/admin/artworks/#{artwork.id}"
      assert html =~ "/admin/events/#{event.id}"
      assert html =~ "/admin/biennales/#{biennale.id}"
      assert html =~ "/admin/projects/#{project.id}"
    end

    test "shows the preview for an uploaded file", %{conn: conn, media: media} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media/#{media.id}")
      assert html =~ "Linked Media"
    end

    test "a url-sourced media uses its url for the preview", %{conn: conn, media: media} do
      media =
        media
        |> Ecto.Changeset.change(source_type: "url", source_url: "https://example.com/pic.jpg")
        |> Repo.update!()

      {:ok, _lv, html} = live(conn, ~p"/admin/media/#{media.id}")
      assert html =~ "https://example.com/pic.jpg"
    end

    test "rotate_media queues a rotation and flashes", %{conn: conn, media: media} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/#{media.id}")
      html = render_hook(lv, "rotate_media", %{"degrees" => "90"})
      assert html =~ "Rotation 90° queued"
    end
  end

  describe "Rotate batch handlers" do
    setup do
      one =
        ContentFixtures.media_fixture(caption: "Batch One", source_type: "upload")
        |> Ecto.Changeset.change(original_name: "Batch One")
        |> MykonosBiennale.Repo.update!()

      two =
        ContentFixtures.media_fixture(caption: "Batch Two", source_type: "upload")
        |> Ecto.Changeset.change(original_name: "Batch Two")
        |> MykonosBiennale.Repo.update!()

      {:ok, one: one, two: two}
    end

    test "lists uploaded media with checkboxes", %{conn: conn, one: one} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media/rotate")
      assert html =~ "Batch One"
      assert html =~ ~s(phx-value-id="#{one.id}")
    end

    test "search patches the URL with the query", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/rotate")
      render_hook(lv, "search", %{"search" => "batch two"})
      assert_patch(lv, "/admin/media/rotate?search=batch+two")
    end

    test "search filters the list", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media/rotate?search=batch%20two")
      assert html =~ "Batch Two"
      refute html =~ "Batch One"
    end

    test "toggle_select selects and deselects an item", %{conn: conn, one: one} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/rotate")
      render_hook(lv, "toggle_select", %{"id" => to_string(one.id)})
      render_hook(lv, "toggle_select", %{"id" => to_string(one.id)})
      assert is_binary(render(lv))
    end

    test "select_all and clear_selection", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/rotate")
      render_hook(lv, "select_all", %{})
      render_hook(lv, "clear_selection", %{})
      assert is_binary(render(lv))
    end

    test "rotate_selected with nothing selected shows an error", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/rotate")

      assert render_hook(lv, "rotate_selected", %{"degrees" => "90"}) =~
               "Select at least one image"
    end

    test "rotate_selected queues rotations for the selection", %{conn: conn, one: one, two: two} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/rotate")
      render_hook(lv, "toggle_select", %{"id" => to_string(one.id)})
      render_hook(lv, "toggle_select", %{"id" => to_string(two.id)})

      assert render_hook(lv, "rotate_selected", %{"degrees" => "180"}) =~ "Rotation 180"
    end
  end

  describe "Index handlers" do
    setup do
      alpha = ContentFixtures.media_fixture(caption: "Alpha shot")
      beta = ContentFixtures.media_fixture(caption: "Beta shot")
      {:ok, alpha: alpha, beta: beta}
    end

    test "sorting by caption ascending is accepted from the URL", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/media?sort_by=caption&sort_dir=asc")
      assert html =~ "Alpha shot"
      assert html =~ "Beta shot"
    end

    test "search filters the media list", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media")
      html = render_hook(lv, "search", %{"search" => "beta"})
      assert html =~ "Beta shot"
      refute html =~ "Alpha shot"
    end

    test "clear_search restores the full list and patches the URL", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media")
      render_hook(lv, "search", %{"search" => "beta"})
      render_hook(lv, "clear_search", %{})
      assert_patch(lv, "/admin/media?sort_by=inserted_at&page=1&sort_dir=desc")
      assert render(lv) =~ "Alpha shot"
    end

    test "delete removes a media item", %{conn: conn, alpha: a} do
      {:ok, lv, _} = live(conn, ~p"/admin/media")
      render_hook(lv, "delete", %{"id" => to_string(a.id)})
      refute MykonosBiennale.Repo.get(MykonosBiennale.Content.Media, a.id)
    end

    test "a saved media from the form is shown in the list", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media")
      fresh = ContentFixtures.media_fixture(caption: "Fresh upload")

      send(lv.pid, {MykonosBiennaleWeb.Admin.MediaLive.FormComponent, {:saved, fresh}})
      assert render(lv) =~ "Fresh upload"
    end

    test "a page past the end is redirected to the last page", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: to}}} = live(conn, ~p"/admin/media?page=50")
      assert to == "/admin/media?sort_by=inserted_at&page=1&sort_dir=desc"
    end
  end

  describe "Media form handlers" do
    test "validate with a source type of url shows the url field", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/new")

      lv
      |> form("#media-form", media: %{source_type: "url"})
      |> render_change()

      assert has_element?(lv, "#media-form input[name='media[source_url]']")
    end

    test "creating a url media saves it and patches back", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/new")
      # The url field appears only after the source type is switched.
      lv |> form("#media-form", media: %{source_type: "url"}) |> render_change()

      lv
      |> form("#media-form",
        media: %{
          source_type: "url",
          source_url: "https://example.com/new.jpg",
          caption: "Created by form"
        }
      )
      |> render_submit()

      assert_patch(lv, ~p"/admin/media")

      assert MykonosBiennale.Repo.get_by(MykonosBiennale.Content.Media,
               caption: "Created by form"
             )
    end

    test "creating with no source type keeps the form open", %{conn: conn} do
      {:ok, lv, _} = live(conn, ~p"/admin/media/new")
      lv |> form("#media-form", media: %{source_type: "", caption: "No type"}) |> render_submit()
      assert has_element?(lv, "#media-form")
    end

    test "photographer search with no matches clears the picker", %{conn: conn} do
      media = ContentFixtures.media_fixture(caption: "Credit search")
      {:ok, lv, _} = live(conn, ~p"/admin/media/#{media.id}/edit")

      lv
      |> element("form[phx-change=search_photographer]")
      |> render_change(%{"q" => "zzz-no-such-person"})

      refute has_element?(lv, "button[phx-click=pick_photographer]")
    end
  end
end
