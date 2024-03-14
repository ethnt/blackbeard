defmodule BlackbeardWeb.Router do
  use BlackbeardWeb, :router

  import BlackbeardWeb.Authentication

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BlackbeardWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BlackbeardWeb do
    pipe_through [:browser, :require_unauthenticated_user]

    get "/login", SessionsController, :new
    post "/login", SessionsController, :create

    get "/invite/:id", UsersInviteController, :edit
    patch "/invite/:id", UsersInviteController, :update
  end

  scope "/", BlackbeardWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", DashboardController, :index

    get "/logout", SessionsController, :destroy

    get "/users", UsersController, :index
    get "/users/new", UsersController, :new
  end

  scope "/api", BlackbeardWeb do
    pipe_through :api
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:blackbeard_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: BlackbeardWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
