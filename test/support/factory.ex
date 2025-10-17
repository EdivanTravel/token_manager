# test/support/factory.ex
defmodule TokenManager.Factory do
  @moduledoc "Factory para criar dados de teste"

  use ExMachina.Ecto, repo: TokenManager.Repo

  alias TokenManager.Tokens.{Token, TokenUsage}

  def token_factory do
    %Token{
      id: Ecto.UUID.generate(),
      token: Ecto.UUID.generate(),
      status: "available",
      user_id: nil,
      activated_at: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def token_usage_factory do
    %TokenUsage{
      id: Ecto.UUID.generate(),
      token_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now(),
      ended_at: nil,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end
end
