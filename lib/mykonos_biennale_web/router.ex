defmodule MykonosBiennaleWeb.Router do
  use MykonosBiennaleWeb, :router

  import MykonosBiennaleWeb.UserAuth

  import Backpex.Router

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
  end

  scope "/admin", MykonosBiennaleWeb do
    pipe_through :browser

    backpex_routes()

    # add these lines
    live_session :default, on_mount: Backpex.InitAssigns do
      live_resources "/pages", Admin.PageLive
      live_resources "/sections", Admin.SectionLive
    end
  end

  scope "/", MykonosBiennaleWeb do
    pipe_through :browser

    get "/", PageController, :home
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
  end

  ## Authentication routes

  scope "/", MykonosBiennaleWeb do
    pipe_through [:browser, :require_authenticated_user]

    backpex_routes()

    live_session :require_authenticated_user,
      on_mount: [{MykonosBiennaleWeb.UserAuth, :require_authenticated}] do
      resources "/pages", PageController
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email

      # Backpex Admin Resources
      live_resources "/admin/pages", Admin.PageLive
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
