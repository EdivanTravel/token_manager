defmodule TokenManager.Workers.TokenReleaser do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"token_id" => token_id}}) do
    alias TokenManager.Tokens
    alias TokenManager.Repo

    case Repo.get(TokenManager.Tokens.Token, token_id) do
      nil ->
        :ok

      token ->
        if token.status == "active" do
          Tokens.release_token(token)
        else
          :ok
        end
    end
  end
end
