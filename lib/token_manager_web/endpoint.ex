defmodule TokenManagerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :token_manager

  @session_options [
    store: :cookie,
    key: "_token_manager_key",
    signing_salt: "3WW9wMxI",
    same_site: "Lax"
  ]

  # Serve arquivos estáticos (se necessário)
  plug Plug.Static,
    at: "/",
    from: :token_manager,
    gzip: false,
    only: TokenManagerWeb.static_paths()

  # Code reloading (útil em dev)
  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :token_manager
  end

  # Middleware padrão para APIs
  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug TokenManagerWeb.Router
end
