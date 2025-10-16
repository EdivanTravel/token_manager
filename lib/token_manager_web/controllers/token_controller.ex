defmodule TokenManagerWeb.TokenController do
  use TokenManagerWeb, :controller
  alias TokenManager.Tokens

  def index(conn, _params) do
    tokens = Tokens.list_tokens()
    json(conn, tokens)
  end

  def allocate(conn, %{"user_id" => user_id}) do
    case Tokens.allocate_token(user_id) do
      {:ok, token} -> json(conn, %{token_id: token.id, user_id: user_id})
      {:error, reason} -> json(conn, %{error: reason})
    end
  end

  def release(conn, %{"id" => id}) do
    token = Tokens.get_token!(id)
    Tokens.release_token(token)
    json(conn, %{status: "released", token_id: id})
  end
end
