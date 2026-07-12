defmodule MykonosBiennaleWeb.RouterCoverageTest do
  use MykonosBiennaleWeb.ConnCase

  @moduledoc """
  Guards against new routes being added without regression tests.
  Every GET/Live route must appear in @tested_routes. If a new route
  is added, this test fails until the route is added here (and a
  regression test is written for it).
  """

  # Every public and admin route that has (or should have) a regression test.
  # Format: {verb_atom, path_pattern_string}
  # Path params are normalized to :id for comparison.
  @tested_routes [
    {:get, "/"},
    {:get, "/media/:dimensions/:filename"},
    {:get, "/media/:filename"},
    {:get, "/archive"},
    {:get, "/archive/:year"},
    {:get, "/program"},
    {:get, "/about"},
    {:get, "/search"},
    {:get, "/page/:slug"},
    {:get, "/art/:id"},
    {:get, "/art/s/:slug"},
    {:get, "/artist/:id"},
    {:get, "/artist/s/:slug"},
    {:get, "/event/:id"},
    {:get, "/event/s/:slug"},
    {:get, "/film/:id"},
    {:get, "/film/s/:slug"},
    {:get, "/biennale/:slug"},
    {:get, "/biennale/:slug/festival"},
    {:get, "/users/settings"},
    {:get, "/users/settings/confirm-email/:token"},
    {:get, "/users/log-in"},
    {:get, "/users/log-in/:token"},
    {:get, "/admin/dashboard"},
    {:get, "/admin/oban"},
    {:get, "/admin"},
    {:get, "/admin/biennales"},
    {:get, "/admin/biennales/new"},
    {:get, "/admin/biennales/:id/edit"},
    {:get, "/admin/biennales/:id"},
    {:get, "/admin/events"},
    {:get, "/admin/events/new"},
    {:get, "/admin/events/:id"},
    {:get, "/admin/events/:id/edit"},
    {:get, "/admin/participants"},
    {:get, "/admin/participants/new"},
    {:get, "/admin/participants/:id/edit"},
    {:get, "/admin/participants/:id/artworks/new"},
    {:get, "/admin/participants/:id"},
    {:get, "/admin/films"},
    {:get, "/admin/films/new"},
    {:get, "/admin/films/:id/edit"},
    {:get, "/admin/films/:id"},
    {:get, "/admin/artworks"},
    {:get, "/admin/artworks/import_preview"},
    {:get, "/admin/artworks/merge"},
    {:get, "/admin/artworks/new"},
    {:get, "/admin/artworks/:id/edit"},
    {:get, "/admin/artworks/:id"},
    {:get, "/admin/projects"},
    {:get, "/admin/projects/new"},
    {:get, "/admin/projects/:id"},
    {:get, "/admin/projects/:id/edit"},
    {:get, "/admin/media"},
    {:get, "/admin/media/new"},
    {:get, "/admin/media/rotate"},
    {:get, "/admin/media/:id"},
    {:get, "/admin/media/:id/edit"},
    {:get, "/admin/pages"},
    {:get, "/admin/pages/new"},
    {:get, "/admin/pages/:id"},
    {:get, "/admin/pages/:id/edit"},
    {:get, "/admin/sections"},
    {:get, "/admin/sections/new"},
    {:get, "/admin/sections/:id"},
    {:get, "/admin/sections/:id/edit"},
    {:get, "/admin/relationship_types"},
    {:get, "/admin/relationship_types/new"},
    {:get, "/admin/relationship_types/:id/edit"},
    {:get, "/admin/relationships"},
    {:get, "/admin/relationships/new"},
    {:get, "/admin/relationships/:id"},
    {:get, "/admin/relationships/:id/edit"},
    {:get, "/admin/users"},
    {:get, "/admin/users/new"},
    {:get, "/admin/users/:id/edit"}
  ]

  defp normalize_path(path) do
    path
  end

  defp excluded?(verb, path) do
    verb not in [:get, :ws] or
      (String.starts_with?(path, "/admin/dashboard/") and path != "/admin/dashboard") or
      (String.starts_with?(path, "/admin/oban/") and path != "/admin/oban") or
      String.starts_with?(path, "/admin/mailbox") or
      (verb in [:post, :delete] and
         path in ["/users/update-password", "/users/log-in", "/users/log-out"])
  end

  test "every GET route is covered in @tested_routes" do
    actual =
      MykonosBiennaleWeb.Router.__routes__()
      |> Enum.reject(fn r -> excluded?(r.verb, r.path) end)
      |> Enum.map(fn r -> {r.verb, normalize_path(r.path)} end)
      |> MapSet.new()

    expected = MapSet.new(@tested_routes)

    missing = MapSet.difference(actual, expected)
    extra = MapSet.difference(expected, actual)

    assert MapSet.size(missing) == 0,
           "Routes missing from @tested_routes (add them and write regression tests):\n" <>
             Enum.join(Enum.map(missing, fn {v, p} -> "#{v} #{p}" end), "\n")

    assert MapSet.size(extra) == 0,
           "Routes in @tested_routes no longer exist in the router (remove them):\n" <>
             Enum.join(Enum.map(extra, fn {v, p} -> "#{v} #{p}" end), "\n")
  end
end
