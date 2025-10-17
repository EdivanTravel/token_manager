defmodule TokenManagerWeb.TokenController do
  use TokenManagerWeb, :controller
  alias TokenManager.Tokens

  @doc """
  Lista todos os tokens (disponíveis e ativos)
  GET /api/tokens
  """
  def index(conn, _params) do
    tokens = Tokens.list_tokens()
    json(conn, tokens)
  end

  @doc """
  Aloca um token para um usuário
  POST /api/tokens/allocate
  Body: {"user_id": "uuid-do-usuario"}
  """
  def allocate(conn, %{"user_id" => user_id}) do
    case Tokens.allocate_token(user_id) do
      {:ok, token} ->
        conn
        |> put_status(:ok)
        |> json(%{
          token_id: token.id,
          user_id: user_id,
          token_value: token.token,
          status: token.status,
          activated_at: token.activated_at
        })

      {:error, :no_tokens_available} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "No tokens available"})

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Internal server error: #{inspect(reason)}"})
    end
  end

  @doc """
  Libera um token específico
  POST /api/tokens/release/:id
  """
  def release(conn, %{"id" => id}) do
    try do
      case Tokens.release_token(id) do
        {:ok, _token} ->
          conn
          |> put_status(:ok)
          |> json(%{status: "released", token_id: id})

        {:error, reason} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "Failed to release token: #{inspect(reason)}"})
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Token not found"})
    end
  end

  @doc """
  Consulta um token específico e seu utilizador atual
  GET /api/tokens/:id
  """
  def show(conn, %{"id" => id}) do
    case Tokens.get_token_with_user(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Token not found"})

      token_info ->
        conn
        |> put_status(:ok)
        |> json(token_info)
    end
  end

  @doc """
  Consulta o histórico de utilização de um token
  GET /api/tokens/:id/history
  """
  def history(conn, %{"id" => id}) do
    case Tokens.get_token_history(id) do
      %{history: []} ->
        conn
        |> put_status(:ok)
        |> json(%{token_id: id, history: [], message: "No usage history found"})

      history_info ->
        conn
        |> put_status(:ok)
        |> json(history_info)
    end
  end

  @doc """
  Limpa todos os tokens ativos
  DELETE /api/tokens/clear-active
  """
  def clear_active(conn, _params) do
    case Tokens.clear_active_tokens() do
      {:ok, result} ->
        conn
        |> put_status(:ok)
        |> json(%{
          message: "All active tokens cleared",
          tokens_cleared: result.tokens_cleared,
          usages_updated: result.usages_updated
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Failed to clear tokens: #{inspect(reason)}"})
    end
  end

  @doc """
  Lista apenas tokens disponíveis
  GET /api/tokens/available
  """
  def available(conn, _params) do
    tokens = Tokens.list_available_tokens()
    json(conn, tokens)
  end

  @doc """
  Lista apenas tokens ativos
  GET /api/tokens/active
  """
  def active(conn, _params) do
    tokens = Tokens.list_active_tokens()
    json(conn, tokens)
  end
end
