defmodule TokenManagerWeb.Router do
  use TokenManagerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TokenManagerWeb do
    pipe_through :api

    # Rotas fixas
    get "/tokens", TokenController, :index
    get "/tokens/available", TokenController, :available
    get "/tokens/active", TokenController, :active
    post "/tokens/allocate", TokenController, :allocate
    delete "/tokens/clear-active", TokenController, :clear_active

    # Rotas com parâmetros
    get "/tokens/:id/history", TokenController, :history
    get "/tokens/:id", TokenController, :show
    post "/tokens/release/:id", TokenController, :release
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:token_manager, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
