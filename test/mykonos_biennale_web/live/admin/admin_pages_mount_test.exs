defmodule MykonosBiennaleWeb.Admin.AdminPagesMountTest do
  @moduledoc """
  Smoke coverage: every admin route mounts for an admin user and renders.
  Deeper behaviour (events, forms, validation) lives in each page's own test file.
  """
  use MykonosBiennaleWeb.AdminCase

  alias MykonosBiennale.ContentFixtures

  setup do
    ContentFixtures.ensure_relationship_types()
    biennale = ContentFixtures.biennale_fixture(year: 2025)
    event = ContentFixtures.event_fixture(biennale: biennale)
    participant = ContentFixtures.participant_fixture()
    artwork = ContentFixtures.artwork_fixture()
    film = ContentFixtures.film_fixture()
    project = ContentFixtures.project_fixture()
    media = ContentFixtures.media_fixture()
    page = SiteFixtures.page_fixture()
    section = SiteFixtures.section_fixture()

    {:ok,
     biennale: biennale,
     event: event,
     participant: participant,
     artwork: artwork,
     film: film,
     project: project,
     media: media,
     page: page,
     section: section}
  end

  @static_paths ~w(
    /admin /admin/biennales /admin/biennales/new /admin/antidote
    /admin/events /admin/events/new /admin/participants /admin/participants/new
    /admin/films /admin/films/new /admin/teams /admin/teams/new
    /admin/sponsors /admin/sponsors/new /admin/artworks /admin/artworks/new
    /admin/artworks/import_preview /admin/artworks/merge
    /admin/projects /admin/projects/new /admin/media /admin/media/new
    /admin/media/rotate /admin/pages /admin/pages/new /admin/sections
    /admin/sections/new /admin/relationship_types /admin/relationship_types/new
    /admin/relationships /admin/relationships/new
  )

  test "static admin pages mount", %{conn: conn} do
    for path <- @static_paths do
      result = live(conn, path)
      assert {:ok, _lv, html} = result, "failed to mount #{path}: #{inspect(result)}"
      assert is_binary(html)
    end
  end

  test "id-based admin pages mount", %{conn: conn} = ctx do
    paths = [
      "/admin/biennales/#{ctx.biennale.id}",
      "/admin/biennales/#{ctx.biennale.id}/edit",
      "/admin/events/#{ctx.event.id}",
      "/admin/events/#{ctx.event.id}/edit",
      "/admin/participants/#{ctx.participant.id}",
      "/admin/participants/#{ctx.participant.id}/edit",
      "/admin/participants/#{ctx.participant.id}/artworks/new",
      "/admin/teams/#{ctx.participant.id}",
      "/admin/films/#{ctx.film.id}",
      "/admin/films/#{ctx.film.id}/edit",
      "/admin/artworks/#{ctx.artwork.id}",
      "/admin/artworks/#{ctx.artwork.id}/edit",
      "/admin/projects/#{ctx.project.id}",
      "/admin/projects/#{ctx.project.id}/edit",
      "/admin/media/#{ctx.media.id}",
      "/admin/media/#{ctx.media.id}/edit",
      "/admin/pages/#{ctx.page.id}",
      "/admin/pages/#{ctx.page.id}/edit",
      "/admin/sections/#{ctx.section.id}",
      "/admin/sections/#{ctx.section.id}/edit"
    ]

    for path <- paths do
      assert {:ok, _lv, html} = live(conn, path), "failed to mount #{path}"
      assert is_binary(html)
    end
  end
end
