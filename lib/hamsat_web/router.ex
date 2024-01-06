defmodule HamsatWeb.Router do
  use HamsatWeb, :router

  import HamsatWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {HamsatWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
    plug HamsatWeb.ContextPlug
    plug HamsatWeb.NavPlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admins_only do
    plug HamsatWeb.AdminsOnlyPlug
  end

  scope "/", HamsatWeb do
    pipe_through [:browser, :require_authenticated_user]
    live "/alerts/new", AlertsLive.New, :new, as: :alerts
    live "/alerts/:id/edit", AlertsLive.New, :edit, as: :alerts
  end

  scope "/", HamsatWeb do
    pipe_through :browser

    live "/", DashboardLive.Show, :show, as: :dashboard

    live "/alerts", AlertsLive.Index, :index, as: :alerts
    live "/alerts/:id", AlertsLive.Show, :show, as: :alerts

    live "/passes", PassesLive.Index, :index, as: :passes

    live "/sats", SatsLive.Index, :index, as: :sats

    live "/location", LocationLive.Edit, :edit, as: :location
    post "/session_location", SessionLocationController, :update
  end

  # Other scopes may use custom stacks.
  # scope "/api", HamsatWeb do
  #   pipe_through :api
  # end

  scope "/" do
    pipe_through [:browser, :admins_only]

    live_dashboard "/ld", metrics: HamsatWeb.Telemetry
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HamsatWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live "/users/register", UserRegistrationLive.New, :new, as: :user_registration

    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
    get "/users/reset_password", UserResetPasswordController, :new
    post "/users/reset_password", UserResetPasswordController, :create
    get "/users/reset_password/:token", UserResetPasswordController, :edit
    put "/users/reset_password/:token", UserResetPasswordController, :update
  end

  scope "/", HamsatWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm_email/:token", UserSettingsController, :confirm_email
  end

  scope "/", HamsatWeb do
    pipe_through [:browser]

    get "/about", PageController, :about
    get "/changelog", PageController, :changelog

    delete "/users/log_out", UserSessionController, :delete
    get "/users/confirm", UserConfirmationController, :new
    post "/users/confirm", UserConfirmationController, :create
    get "/users/confirm/:token", UserConfirmationController, :edit
    post "/users/confirm/:token", UserConfirmationController, :update
  end
end
