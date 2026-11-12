defmodule MykonosBiennaleWeb.Admin.FilmLiveTest do
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.Content.Entity

  describe "Index" do
    test "lists films", %{conn: conn} do
      _film = ContentFixtures.film_fixture(title: "Test Film Title")
      {:ok, _lv, html} = live(conn, ~p"/admin/films")
      assert html =~ "Test Film Title"
    end

    test "has + New link", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/films")
      assert html =~ "/admin/films/new"
    end
  end

  describe "New" do
    test "renders form", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")
      html = lv |> element("#film-form") |> render()
      assert html =~ "title"
    end

    test "creates film on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")

      lv
      |> form("#film-form", film: %{title: "New Film", type: "Short Film"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/films")
    end

    test "shows errors on invalid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/films/new")

      html =
        lv
        |> form("#film-form", film: %{title: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit" do
    test "renders form with existing data", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Edit Film")
      {:ok, lv, _html} = live(conn, ~p"/admin/films/#{film.id}/edit")
      html = lv |> element("#film-form") |> render()
      assert html =~ "Edit Film"
    end

    test "updates film on valid submit", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Old Film Title")
      {:ok, lv, _html} = live(conn, ~p"/admin/films/#{film.id}/edit")

      lv
      |> form("#film-form", film: %{title: "Updated Film"})
      |> render_submit()

      assert_patch(lv, ~p"/admin/films")
    end
  end

  describe "Show" do
    test "renders film details", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Show Film")
      {:ok, _lv, html} = live(conn, ~p"/admin/films/#{film.id}")
      assert html =~ "Show Film"
    end
  end

  describe "Delete" do
    test "deletes film from index", %{conn: conn} do
      film = ContentFixtures.film_fixture(title: "Delete Film")
      {:ok, lv, _html} = live(conn, ~p"/admin/films")
      lv |> element("[phx-click=delete][phx-value-id='#{film.id}']") |> render_click()
      refute has_element?(lv, "td", "Delete Film")
    end
  end

  describe "Form media and relationships" do
    setup do
      ContentFixtures.ensure_relationship_types()
      film = ContentFixtures.film_fixture(title: "Media Film")
      poster = ContentFixtures.media_fixture(caption: "Film poster")
      trailer = ContentFixtures.media_fixture(caption: "Film trailer")
      copy = ContentFixtures.media_fixture(caption: "Film copy")
      still = ContentFixtures.media_fixture(caption: "Film still")

      Content.attach_media_to_entity(film, poster, metadata: %{"role" => "poster"})
      Content.attach_media_to_entity(film, trailer, metadata: %{"role" => "trailer"})
      Content.attach_media_to_entity(film, copy, metadata: %{"role" => "screening_copy"})
      Content.attach_media_to_entity(film, still, metadata: %{})

      participant = ContentFixtures.participant_fixture(first_name: "Film", last_name: "Director")

      {:ok,
       film: film,
       poster: poster,
       trailer: trailer,
       copy: copy,
       still: still,
       participant: participant}
    end

    test "detach_poster removes the poster", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")
      lv |> element("button[phx-click=detach_poster]") |> render_click()
      refute has_element?(lv, "button[phx-click=detach_poster]")
    end

    test "detach_trailer removes the trailer", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")
      lv |> element("button[phx-click=detach_trailer]") |> render_click()
      refute has_element?(lv, "button[phx-click=detach_trailer]")
    end

    test "detach_screening_copy removes the screening copy", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")
      lv |> element("button[phx-click=detach_screening_copy]") |> render_click()
      refute has_element?(lv, "button[phx-click=detach_screening_copy]")
    end

    test "detach_media removes a still", %{conn: conn, film: f, still: st} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")

      lv
      |> element("button[phx-click=detach_media][phx-value-media-id=\"#{st.id}\"]")
      |> render_click()

      refute has_element?(lv, "button[phx-click=detach_media][phx-value-media-id=\"#{st.id}\"]")
    end

    test "attach_relationship with a type and participant links them", %{
      conn: conn,
      film: f,
      participant: p
    } do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")

      lv
      |> form("form[phx-submit=attach_relationship]",
        relationship_slug: "directed",
        participant_id: to_string(p.id),
        role: "Director"
      )
      |> render_submit()

      assert Content.Film.list_relationships(f) |> Enum.any?(&(&1.object_id == p.id))
    end

    test "attach_relationship with no type does nothing", %{conn: conn, film: f, participant: p} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")

      lv
      |> form("form[phx-submit=attach_relationship]",
        relationship_slug: "",
        participant_id: to_string(p.id)
      )
      |> render_submit()

      refute Enum.any?(Content.Film.list_relationships(f), &(&1.object_id == p.id))
    end

    test "detach_relationship removes a linked participant", %{
      conn: conn,
      film: f,
      participant: p
    } do
      {:ok, rel} = ContentFixtures.create_relationship(f, p, "directed")
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")

      lv
      |> element("button[phx-click=detach_relationship][phx-value-rel-id=\"#{rel.id}\"]")
      |> render_click()

      refute Enum.any?(Content.Film.list_relationships(f), &(&1.object_id == p.id))
    end

    test "validate and a blank-title save keep the form open", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}/edit")
      lv |> form("#film-form", film: %{title: ""}) |> render_change()
      lv |> form("#film-form", film: %{title: ""}) |> render_submit()
      assert has_element?(lv, "#film-form")
    end
  end

  describe "Show linked data and handlers" do
    setup do
      ContentFixtures.ensure_relationship_types()
      film = ContentFixtures.film_fixture(title: "Shown Film")
      event = ContentFixtures.event_fixture(title: "Screening Night")
      {:ok, _} = ContentFixtures.create_relationship(film, event, "screened_at")

      poster = ContentFixtures.media_fixture(caption: "Film poster")
      Content.attach_media_to_entity(film, poster, metadata: %{"role" => "poster"})

      {:ok, film: film, event: event}
    end

    test "shows the film with its screening event and poster", %{conn: conn, film: f, event: e} do
      {:ok, _lv, html} = live(conn, ~p"/admin/films/#{f.id}")
      assert html =~ "Shown Film"
      assert html =~ "Screening Night"
      assert html =~ "/admin/events/#{e.id}"
    end

    test "switch_tab changes the active tab", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}")
      lv |> element("button[phx-click=switch_tab][phx-value-tab=fields]") |> render_click()
      assert has_element?(lv, "button[phx-click=switch_tab][phx-value-tab=fields]")
    end

    test "fields_changed info stores edited film fields", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}")

      send(
        lv.pid,
        {:fields_changed, %{content: ~s({"title": "Edited Film", "type": "Short Film"})}}
      )

      _ = render(lv)
      assert MykonosBiennale.Repo.get!(Entity, f.id).fields["title"] == "Edited Film"

      send(lv.pid, {:fields_changed, %{content: "bad json"}})
      _ = render(lv)
      assert MykonosBiennale.Repo.get!(Entity, f.id).fields["title"] == "Edited Film"
    end

    test "delete removes the film and returns to the index", %{conn: conn, film: f} do
      {:ok, lv, _} = live(conn, ~p"/admin/films/#{f.id}")
      lv |> element("button[phx-click=delete]") |> render_click()
      assert_redirect(lv, "/admin/films")
      refute MykonosBiennale.Repo.get(Entity, f.id)
    end
  end
end
