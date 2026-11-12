defmodule MykonosBiennaleWeb.PublicViewsTest do
  use MykonosBiennaleWeb.ConnCase

  import Phoenix.LiveViewTest
  import Ecto.Query, only: [from: 2]

  alias MykonosBiennale.Content
  alias MykonosBiennale.Content.Entity
  alias MykonosBiennale.GoldenFixtures
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Search.Indexer
  alias MykonosBiennale.Settings
  alias MykonosBiennale.SiteFixtures

  setup do
    ids = GoldenFixtures.load_golden_data!()
    %{golden: ids}
  end

  defp golden_biennale(ids), do: Content.get_entity!(ids.biennale)

  defp film_id do
    Repo.one(
      from e in Entity,
        where: e.type in ["Short Film", "Video", "Dance", "Animation", "Documentary"],
        order_by: e.id,
        limit: 1,
        select: e.id
    )
  end

  describe "home page /" do
    test "renders the biennale for the current year", %{conn: conn} do
      :ok = Settings.put_current_biennale_year(2025)
      html = html_response(get(conn, ~p"/"), 200)
      assert html =~ "Mykonos"
    end

    test "renders without a biennale for an empty year", %{conn: conn} do
      :ok = Settings.put_current_biennale_year(1999)
      assert html_response(get(conn, ~p"/"), 200)
    end
  end

  describe "biennale templates" do
    for template <-
          ~w(festival festival-2023 festival-2025 festival-2027 summary list none default biennale) do
      test "renders the #{template} template", %{conn: conn, golden: ids} do
        biennale = golden_biennale(ids)

        {:ok, _} =
          Content.update_entity(biennale, %{
            fields: Map.put(biennale.fields, "template", unquote(template))
          })

        assert html_response(get(conn, "/biennale/2025"), 200)
      end
    end
  end

  describe "film pages" do
    test "renders a film by id", %{conn: conn} do
      id = film_id()
      assert id, "golden data should include a film"
      assert html_response(get(conn, "/film/#{id}"), 200)
    end

    test "renders a film by slug", %{conn: conn} do
      film = Content.get_entity!(film_id())
      assert html_response(get(conn, "/film/s/#{film.slug}"), 200)
    end

    test "404 for unknown film id", %{conn: conn} do
      assert conn |> get("/film/999999") |> response(404)
    end

    test "404 for unknown film slug", %{conn: conn} do
      assert conn |> get("/film/s/no-such-film") |> response(404)
    end
  end

  describe "site pages /page/:slug" do
    test "renders a visible page", %{conn: conn} do
      page = SiteFixtures.page_fixture(slug: "about-us", content: "<p>Hello page</p>")
      html = html_response(get(conn, "/page/#{page.slug}"), 200)
      assert html =~ "Hello page"
    end

    test "404 for a hidden page", %{conn: conn} do
      page = SiteFixtures.page_fixture(slug: "hidden-page", visible: false)
      assert conn |> get("/page/#{page.slug}") |> response(404)
    end

    test "404 for an unknown page", %{conn: conn} do
      assert conn |> get("/page/nope") |> response(404)
    end
  end

  describe "program /program" do
    test "renders", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/program")
      assert is_binary(html)
    end
  end

  describe "archive detail /archive/:year" do
    test "renders the golden biennale", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/archive/2025")
      assert html =~ "2025"
    end

    test "redirects to the archive for an unknown year", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/archive"}}} = live(conn, "/archive/1990")
    end
  end

  describe "search results /search" do
    setup %{golden: ids} do
      for %{id: id} <- Repo.all(Entity), do: Indexer.index_entity(id)
      %{ids: ids}
    end

    test "finds an artwork by title", %{conn: conn, ids: ids} do
      title = Content.get_entity!(ids.artwork).identity
      {:ok, _lv, html} = live(conn, "/search?q=" <> URI.encode_www_form(title))
      assert html =~ title
    end

    test "finds an artist, an event and a film", %{conn: conn, ids: ids} do
      for id <- [ids.artist, ids.exhibition_event, ids.screening_event] do
        term = Content.get_entity!(id).identity
        {:ok, _lv, html} = live(conn, "/search?q=" <> URI.encode_www_form(term))
        assert html =~ "Search"
      end
    end
  end

  describe "search /search" do
    test "renders an empty search", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/search")
      assert html =~ "Search"
    end

    test "returns results for a query", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/search?q=a")
      assert is_binary(html)
    end

    test "clear event resets the query", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/search?q=a")
      html = render_click(lv, "clear", %{})
      assert is_binary(html)
    end

    test "search event submits a query", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/search")
      html = render_submit(lv, "search", %{"q" => "biennale"})
      assert is_binary(html)
    end
  end

  describe "error pages" do
    test "ErrorHTML renders 404 and 500 templates" do
      assert MykonosBiennaleWeb.ErrorHTML.render("404.html", %{}) =~ "Not Found"
      assert MykonosBiennaleWeb.ErrorHTML.render("500.html", %{}) =~ "Internal"
    end
  end
end
