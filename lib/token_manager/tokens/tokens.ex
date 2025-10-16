defmodule TokenManager.Tokens do
  @moduledoc "Contexto responsável por gerenciar tokens e histórico de uso."
  import Ecto.Query
  alias TokenManager.Repo
  alias TokenManager.Tokens.{Token, TokenUsage}

  @max_active_tokens 100
  @token_expiration_seconds 120

  # Lista todos os tokens
  def list_tokens do
    Repo.all(Token)
  end

  # Lista tokens disponíveis
  def list_available_tokens do
    Repo.all(from t in Token, where: t.status == "available")
  end

  # Lista tokens ativos
  def list_active_tokens do
    Repo.all(from t in Token, where: t.status == "active")
  end

  # Obtém um token específico
  def get_token!(id), do: Repo.get!(Token, id)

  # Solicitar um token para um usuário
  def allocate_token(user_id) do
    now = DateTime.utc_now()

    active_count = Repo.aggregate(from(t in Token, where: t.status == "active"), :count)
    available_token = Repo.one(from t in Token, where: t.status == "available", limit: 1)

    cond do
      available_token != nil ->
        activate_token(available_token, user_id, now)

      active_count >= @max_active_tokens ->
        # libera o token mais antigo e aloca o novo
        oldest_token =
          from(t in Token,
            where: t.status == "active",
            order_by: [asc: t.activated_at],
            limit: 1
          )
          |> Repo.one()

        release_token(oldest_token)
        allocate_token(user_id)

      true ->
        {:error, :no_tokens_available}
    end
  end

  # Ativa um token
  defp activate_token(token, user_id, now) do
    Repo.transaction(fn ->
      {:ok, updated} =
        token
        |> Ecto.Changeset.change(%{
          status: "active",
          activated_at: now,
          user_id: user_id
        })
        |> Repo.update()

      %TokenUsage{}
      |> TokenUsage.changeset(%{
        token_id: updated.id,
        user_id: user_id,
        started_at: now
      })
      |> Repo.insert!()

      # Agenda liberação após 2 minutos (job supervisionado)
      TokenManager.TokenReleaser.schedule_release(updated.id, @token_expiration_seconds)
      updated
    end)
  end

  # Libera manualmente (ou automaticamente) um token ativo
  def release_token(%Token{} = token) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      # Atualiza token
      {:ok, updated} =
        token
        |> Ecto.Changeset.change(%{
          status: "available",
          activated_at: nil,
          user_id: nil
        })
        |> Repo.update()

      # Atualiza histórico
      from(u in TokenUsage,
        where: u.token_id == ^token.id and is_nil(u.ended_at)
      )
      |> Repo.update_all(set: [ended_at: now])

      updated
    end)
  end
end
