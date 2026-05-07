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

  scope "/", MykonosBiennaleWeb do
    pipe_through :browser

    live "/", BiennaleLive
    live "/archive", ArchiveLive
    live "/archive/:year", ArchiveDetailLive
    live "/program", ProgramLive
    live "/about", AboutLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", MykonosBiennaleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:mykonos_biennale, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MykonosBiennaleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end

  ## Authentication routes

  scope "/", MykonosBiennaleWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{MykonosBiennaleWeb.UserAuth, :require_authenticated}] do
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
      live "/admin/participants/:id", Admin.ParticipantLive.Show, :show
      live "/admin/films", Admin.FilmLive.Index, :index
      live "/admin/films/new", Admin.FilmLive.Index, :new
      live "/admin/films/:id/edit", Admin.FilmLive.Index, :edit
      live "/admin/films/:id", Admin.FilmLive.Show, :show
      live "/admin/artworks", Admin.ArtworkLive.Index, :index
      live "/admin/artworks/merge", Admin.ArtworkLive.Merge, :index
      live "/admin/artworks/new", Admin.ArtworkLive.Index, :new
      live "/admin/artworks/:id/edit", Admin.ArtworkLive.Index, :edit
      live "/admin/artworks/:id", Admin.ArtworkLive.Show, :show
      live "/admin/festivals", Admin.FestivalLive.Index, :index
      live "/admin/festivals/new", Admin.FestivalLive.Index, :new
      live "/admin/festivals/:id/edit", Admin.FestivalLive.Index, :edit
      live "/admin/festivals/:id", Admin.FestivalLive.Index, :show
      live "/admin/projects", Admin.ProjectLive.Index, :index
      live "/admin/projects/new", Admin.ProjectLive.Index, :new
      live "/admin/projects/:id", Admin.ProjectLive.Show, :show
      live "/admin/projects/:id/edit", Admin.ProjectLive.Index, :edit
      live "/admin/media", Admin.MediaLive.Index, :index
      live "/admin/media/new", Admin.MediaLive.Index, :new
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
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", MykonosBiennaleWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{MykonosBiennaleWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
