defmodule TokenManager.Tokens.ExpiredTokensCleaner do
  use Oban.Worker, queue: :default, max_attempts: 1

  import Ecto.Query, only: [from: 2]
  alias TokenManager.{Repo, Tokens}

  @impl Oban.Worker
  def perform(_job) do
    # Tokens ativos há mais de 2 minutos
    expired_time = DateTime.utc_now() |> DateTime.add(-120, :second)

    expired_tokens =
      Repo.all(
        from t in TokenManager.Tokens.Token,
          where: t.status == "active" and t.activated_at < ^expired_time
      )

    results =
      Enum.map(expired_tokens, fn token ->
        case Tokens.release_token(token) do
          {:ok, _} -> {:ok, token.id}
          error -> error
        end
      end)

    %{cleaned: length(expired_tokens), results: results}
  end
end
