defmodule MykonosBiennaleWeb.Router do
  use MykonosBiennaleWeb, :router

  import Oban.Web.Router
  import MykonosBiennaleWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MykonosBiennaleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :static_media do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  scope "/", MykonosBiennaleWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/media", MykonosBiennaleWeb do
    pipe_through :static_media

    get "/:dimensions/:filename", MediaController, :show
    get "/:filename", MediaController, :show_slug
  end

  scope "/", MykonosBiennaleWeb do
    pipe_through :browser
    live "/archive", ArchiveLive
    live "/archive/:year", ArchiveDetailLive
    live "/program", ProgramLive
    live "/about", AboutLive
    live "/search", PublicSearchLive
    get "/page/:slug", SitePageController, :show
    get "/art/:id", ArtworkController, :show
    get "/art/s/:slug", ArtworkController, :show_by_slug
    get "/artist/:id", ParticipantController, :show
    get "/artist/s/:slug", ParticipantController, :show_by_slug
    get "/event/:id", EventController, :show
    get "/event/s/:slug", EventController, :show_by_slug
    get "/biennale/:slug", BiennaleController, :show
    get "/biennale/:slug/festival", BiennaleController, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", MykonosBiennaleWeb do
  #   pipe_through :api
  # end

  import Phoenix.LiveDashboard.Router

  # Admin-only dashboards (available in all environments)
  scope "/admin", MykonosBiennaleWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    live_dashboard "/dashboard",
      metrics: MykonosBiennaleWeb.Telemetry,
      ecto_repos: [MykonosBiennale.Repo],
      ecto_psql_extras_options: [long_running_queries: [threshold: "200 milliseconds"]]

    oban_dashboard("/oban")
  end

  # Enable Swoosh mailbox preview in development only
  if Application.compile_env(:mykonos_biennale, :dev_routes) do
    scope "/admin" do
      pipe_through [:browser, :require_authenticated_user, :require_admin]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", MykonosBiennaleWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :admin,
      on_mount: [
        {MykonosBiennaleWeb.UserAuth, :require_authenticated},
        {MykonosBiennaleWeb.UserAuth, :admin_nav_assigns}
      ],
      root_layout: {MykonosBiennaleWeb.Layouts, :admin_root} do
      live "/admin", Admin.DashboardLive
      live "/admin/biennales", Admin.BiennaleLive.Index, :index
      live "/admin/biennales/new", Admin.BiennaleLive.Index, :new
      live "/admin/biennales/:id/edit", Admin.BiennaleLive.Index, :edit
      live "/admin/biennales/:id", Admin.BiennaleLive.Show, :show
      live "/admin/events", Admin.EventLive.Index, :index
      live "/admin/events/new", Admin.EventLive.Index, :new
      live "/admin/events/:id", Admin.EventLive.Show, :show
      live "/admin/events/:id/edit", Admin.EventLive.Index, :edit
      live "/admin/participants", Admin.ParticipantLive.Index, :index
      live "/admin/participants/new", Admin.ParticipantLive.Index, :new
      live "/admin/participants/:id/edit", Admin.ParticipantLive.Index, :edit
      live "/admin/participants/:id/artworks/new", Admin.ParticipantLive.Show, :new_artwork
      live "/admin/participants/:id", Admin.ParticipantLive.Show, :show
      live "/admin/films", Admin.FilmLive.Index, :index
      live "/admin/films/new", Admin.FilmLive.Index, :new
      live "/admin/films/:id/edit", Admin.FilmLive.Index, :edit
      live "/admin/films/:id", Admin.FilmLive.Show, :show
      live "/admin/artworks", Admin.ArtworkLive.Index, :index
      live "/admin/artworks/import_preview", Admin.ArtworkLive.ReimportPreview, :index
      live "/admin/artworks/merge", Admin.ArtworkLive.Merge, :index
      live "/admin/artworks/new", Admin.ArtworkLive.Index, :new
      live "/admin/artworks/:id/edit", Admin.ArtworkLive.Index, :edit
      live "/admin/artworks/:id", Admin.ArtworkLive.Show, :show
      live "/admin/projects", Admin.ProjectLive.Index, :index
      live "/admin/projects/new", Admin.ProjectLive.Index, :new
      live "/admin/projects/:id", Admin.ProjectLive.Show, :show
      live "/admin/projects/:id/edit", Admin.ProjectLive.Index, :edit
      live "/admin/media", Admin.MediaLive.Index, :index
      live "/admin/media/new", Admin.MediaLive.Index, :new
      live "/admin/media/rotate", Admin.MediaLive.Rotate, :index
      live "/admin/media/:id", Admin.MediaLive.Show, :show
      live "/admin/media/:id/edit", Admin.MediaLive.Index, :edit
      live "/admin/pages", Admin.PageLive.Index, :index
      live "/admin/pages/new", Admin.PageLive.Index, :new
      live "/admin/pages/:id", Admin.PageLive.Show, :show
      live "/admin/pages/:id/edit", Admin.PageLive.Index, :edit
      live "/admin/sections", Admin.SectionLive.Index, :index
      live "/admin/sections/new", Admin.SectionLive.Index, :new
      live "/admin/sections/:id", Admin.SectionLive.Show, :show
      live "/admin/sections/:id/edit", Admin.SectionLive.Index, :edit
      live "/admin/relationship_types", Admin.RelationshipTypeLive.Index, :index
      live "/admin/relationship_types/new", Admin.RelationshipTypeLive.Index, :new
      live "/admin/relationship_types/:id/edit", Admin.RelationshipTypeLive.Index, :edit
      live "/admin/relationships", Admin.RelationshipLive.Index, :index
      live "/admin/relationships/new", Admin.RelationshipLive.Index, :new
      live "/admin/relationships/:id", Admin.RelationshipLive.Show, :show
      live "/admin/relationships/:id/edit", Admin.RelationshipLive.Index, :edit
    end

    live_session :admin_users,
      on_mount: [
        {MykonosBiennaleWeb.UserAuth, :require_authenticated},
        {MykonosBiennaleWeb.UserAuth, :require_admin},
        {MykonosBiennaleWeb.UserAuth, :admin_nav_assigns}
      ],
      root_layout: {MykonosBiennaleWeb.Layouts, :admin_root} do
      live "/admin/users", Admin.UserLive.Index, :index
      live "/admin/users/new", Admin.UserLive.Index, :new
      live "/admin/users/:id/edit", Admin.UserLive.Index, :edit
    end

    live_session :require_authenticated_user,
      on_mount: [{MykonosBiennaleWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", MykonosBiennaleWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{MykonosBiennaleWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
