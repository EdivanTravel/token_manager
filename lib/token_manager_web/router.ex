defmodule TokenManagerWeb.Router do
  use TokenManagerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TokenManagerWeb do
    pipe_through :api

    get "/tokens", TokenController, :index
    get "/tokens/available", TokenController, :available
    get "/tokens/active", TokenController, :active
    post "/tokens/allocate", TokenController, :allocate
    delete "/tokens/clear-active", TokenController, :clear_active
    get "/tokens/:id/history", TokenController, :history
    get "/tokens/:id", TokenController, :show
    post "/tokens/release/:id", TokenController, :release
  end

  if Application.compile_env(:token_manager, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
