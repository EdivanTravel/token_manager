defmodule TokenManager.Application do

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TokenManagerWeb.Telemetry,
      TokenManager.Repo,
      {Oban, Application.fetch_env!(:token_manager, Oban)},
      {DNSCluster, query: Application.get_env(:token_manager, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TokenManager.PubSub},
      {Finch, name: TokenManager.Finch},
      TokenManagerWeb.Endpoint
    ]


    opts = [strategy: :one_for_one, name: TokenManager.Supervisor]
    Supervisor.start_link(children, opts)
  end


  @impl true
  def config_change(changed, _new, removed) do
    TokenManagerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
