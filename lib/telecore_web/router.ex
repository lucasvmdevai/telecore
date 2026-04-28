defmodule TelecoreWeb.Router do
  use TelecoreWeb, :router

  import TelecoreWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TelecoreWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug TelecoreWeb.Plugs.ApiAuth
  end

  scope "/", TelecoreWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", TelecoreWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:telecore, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TelecoreWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TelecoreWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TelecoreWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", TelecoreWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{TelecoreWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  # JSON API — public (no auth required).
  # New endpoints that DO need auth go in the :api_authenticated scope below.
  scope "/api/v1", TelecoreWeb.Api.V1 do
    pipe_through :api

    post "/sessions", SessionController, :create
    post "/users", UserController, :create
  end

  # JSON API — Bearer-token authenticated.
  # The :api_authenticated pipeline runs TelecoreWeb.Plugs.ApiAuth which
  # halts with 401 if the request lacks a valid `Authorization: Bearer <token>`.
  scope "/api/v1", TelecoreWeb.Api.V1 do
    pipe_through :api_authenticated

    delete "/sessions", SessionController, :delete
    get "/users/me", UserController, :me
  end
end
