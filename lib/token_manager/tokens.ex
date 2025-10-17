# lib/token_manager/tokens.ex
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

  # Consulta token com informações do usuário atual
  def get_token_with_user(token_id) do
    token = Repo.get(Token, token_id)

    if token do
      current_user =
        if token.status == "active" do
          %{user_id: token.user_id, activated_at: token.activated_at}
        end

      %{
        token: token,
        current_user: current_user
      }
    end
  end

  # Consulta histórico de uso
  def get_token_history(token_id) do
    usages =
      Repo.all(
        from u in TokenUsage,
          where: u.token_id == ^token_id,
          order_by: [desc: u.started_at]
      )

    %{
      token_id: token_id,
      history: usages
    }
  end

  # Aloca token para usuário
  def allocate_token(user_id) do
    user_uuid =
      if is_binary(user_id) and
           not String.match?(
             user_id,
             ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
           ) do
        :crypto.hash(:md5, user_id)
        |> Base.encode16(case: :lower)
        |> String.slice(0, 32)
        |> then(fn hash ->
          <<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>> = hash
          "#{a}-#{b}-#{c}-#{d}-#{e}"
        end)
      else
        user_id
      end

    Repo.transaction(fn ->
      with {:ok, token} <- find_or_make_token_available(user_uuid),
           {:ok, activated_token} <- activate_token(token, user_uuid) do
        activated_token
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp find_or_make_token_available(user_id) do
    available_token =
      Repo.one(
        from t in Token,
          where: t.status == "available",
          limit: 1,
          lock: "FOR UPDATE"
      )

    cond do
      available_token ->
        {:ok, available_token}

      true ->
        # Libera o token mais antigo
        oldest_token =
          Repo.one(
            from t in Token,
              where: t.status == "active",
              order_by: [asc: t.activated_at],
              limit: 1,
              lock: "FOR UPDATE"
          )

        if oldest_token do
          release_token(oldest_token)
          find_or_make_token_available(user_id)
        else
          {:error, :no_tokens_available}
        end
    end
  end

  defp activate_token(token, user_id) do
    now = DateTime.utc_now()

    # Atualiza token
    {:ok, updated_token} =
      token
      |> Token.changeset(%{
        status: "active",
        user_id: user_id,
        activated_at: now
      })
      |> Repo.update()

    # Registra no histórico
    {:ok, _usage} =
      %TokenUsage{}
      |> TokenUsage.changeset(%{
        token_id: updated_token.id,
        user_id: user_id,
        started_at: now
      })
      |> Repo.insert()

    # Agenda liberação automática com Oban
    schedule_token_release(updated_token.id)

    {:ok, updated_token}
  end

  # Libera token
  def release_token(%Token{} = token) do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      # Atualiza token
      {:ok, updated_token} =
        token
        |> Token.changeset(%{
          status: "available",
          user_id: nil,
          activated_at: nil
        })
        |> Repo.update()

      # Atualiza histórico
      from(u in TokenUsage,
        where: u.token_id == ^token.id and is_nil(u.ended_at)
      )
      |> Repo.update_all(set: [ended_at: now])

      updated_token
    end)
  end

  def release_token(token_id) when is_binary(token_id) do
    token = get_token!(token_id)
    release_token(token)
  end

  # Limpa todos os tokens ativos
  def clear_active_tokens do
    now = DateTime.utc_now()

    Repo.transaction(fn ->
      # Busca tokens ativos
      active_tokens = Repo.all(from t in Token, where: t.status == "active")
      active_token_ids = Enum.map(active_tokens, & &1.id)

      # Atualiza tokens
      {token_count, _} =
        Repo.update_all(
          from(t in Token, where: t.status == "active"),
          set: [status: "available", user_id: nil, activated_at: nil]
        )

      # Atualiza históricos
      {usage_count, _} =
        Repo.update_all(
          from(u in TokenUsage, where: u.token_id in ^active_token_ids and is_nil(u.ended_at)),
          set: [ended_at: now]
        )

      %{tokens_cleared: token_count, usages_updated: usage_count}
    end)
  end

  # Agenda liberação com Oban
  defp schedule_token_release(token_id) do
    %{token_id: token_id}
    |> TokenManager.Workers.TokenReleaser.new(schedule_in: @token_expiration_seconds)
    |> Oban.insert()
  end
end
