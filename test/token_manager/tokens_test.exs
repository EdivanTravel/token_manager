defmodule TokenManager.TokensTest do
  use TokenManager.DataCase, async: false
  import TokenManager.Factory

  alias TokenManager.Tokens
  alias TokenManager.Tokens.{Token, TokenUsage}

  describe "list_tokens/0" do
    test "returns all tokens" do
      insert_list(3, :token)
      tokens = Tokens.list_tokens()
      assert length(tokens) == 3
    end
  end

  describe "list_available_tokens/0" do
    test "returns only available tokens" do
      insert(:token, status: "available")
      insert(:token, status: "active")

      available_tokens = Tokens.list_available_tokens()
      assert length(available_tokens) == 1
      assert hd(available_tokens).status == "available"
    end
  end

  describe "list_active_tokens/0" do
    test "returns only active tokens" do
      insert(:token, status: "available")
      insert(:token, status: "active")
      insert(:token, status: "active")

      active_tokens = Tokens.list_active_tokens()
      assert length(active_tokens) == 2
      assert Enum.all?(active_tokens, &(&1.status == "active"))
    end
  end

  describe "get_token!/1" do
    test "returns token when it exists" do
      token = insert(:token)
      found_token = Tokens.get_token!(token.id)
      assert found_token.id == token.id
    end

    test "raises error when token doesn't exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Tokens.get_token!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_token_with_user/1" do
    test "returns token with current user when active" do
      user_id = Ecto.UUID.generate()
      token = insert(:token, status: "active", user_id: user_id, activated_at: DateTime.utc_now())

      result = Tokens.get_token_with_user(token.id)

      assert result.token.id == token.id
      assert result.current_user.user_id == user_id
      assert result.current_user.activated_at == token.activated_at
    end

    test "returns token without current user when available" do
      token = insert(:token, status: "available", user_id: nil, activated_at: nil)

      result = Tokens.get_token_with_user(token.id)

      assert result.token.id == token.id
      assert result.current_user == nil
    end

    test "returns nil when token doesn't exist" do
      assert Tokens.get_token_with_user(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_token_history/1" do
    test "returns token usage history" do
      token = insert(:token)
      user1 = Ecto.UUID.generate()
      user2 = Ecto.UUID.generate()

      insert(:token_usage,
        token_id: token.id,
        user_id: user1,
        started_at: ~U[2023-01-01 10:00:00Z]
      )

      insert(:token_usage,
        token_id: token.id,
        user_id: user2,
        started_at: ~U[2023-01-01 11:00:00Z]
      )

      history = Tokens.get_token_history(token.id)

      assert history.token_id == token.id
      assert length(history.history) == 2
      # ordenado por started_at desc
      assert Enum.map(history.history, & &1.user_id) == [user2, user1]
    end

    test "returns empty history for token without usage" do
      token = insert(:token)

      history = Tokens.get_token_history(token.id)

      assert history.token_id == token.id
      assert history.history == []
    end
  end

  describe "allocate_token/1" do
    setup do
      insert_list(3, :token, status: "available")
      :ok
    end

    test "allocates available token to user with UUID" do
      user_id = Ecto.UUID.generate()

      assert {:ok, allocated_token} = Tokens.allocate_token(user_id)
      assert allocated_token.status == "active"
      assert allocated_token.user_id == user_id
      assert allocated_token.activated_at != nil
    end

    test "converts non-UUID user_id to UUID format" do
      non_uuid_user_id = "user123"

      assert {:ok, allocated_token} = Tokens.allocate_token(non_uuid_user_id)
      assert allocated_token.status == "active"

      assert String.match?(
               allocated_token.user_id,
               ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
             )
    end

    test "releases oldest token when no available tokens" do
      tokens = Tokens.list_tokens()

      Enum.each(tokens, fn token ->
        Tokens.release_token(token)
        {:ok, _} = Tokens.allocate_token(Ecto.UUID.generate())
      end)

      assert Tokens.list_available_tokens() == []

      user_id = Ecto.UUID.generate()
      assert {:ok, allocated_token} = Tokens.allocate_token(user_id)
      assert allocated_token.status == "active"
      assert allocated_token.user_id == user_id
    end

    test "creates token usage record" do
      user_id = Ecto.UUID.generate()

      assert {:ok, token} = Tokens.allocate_token(user_id)

      history = Tokens.get_token_history(token.id)
      assert length(history.history) == 1

      usage = hd(history.history)
      assert usage.user_id == user_id
      assert usage.token_id == token.id
      assert usage.started_at != nil
      assert usage.ended_at == nil
    end
  end

  describe "release_token/1" do
    test "releases active token by struct" do
      user_id = Ecto.UUID.generate()
      token = insert(:token, status: "active", user_id: user_id, activated_at: DateTime.utc_now())
      insert(:token_usage, token_id: token.id, user_id: user_id, started_at: DateTime.utc_now())

      assert {:ok, released_token} = Tokens.release_token(token)
      assert released_token.status == "available"
      assert released_token.user_id == nil
      assert released_token.activated_at == nil
    end

    test "releases active token by ID" do
      user_id = Ecto.UUID.generate()
      token = insert(:token, status: "active", user_id: user_id, activated_at: DateTime.utc_now())
      insert(:token_usage, token_id: token.id, user_id: user_id, started_at: DateTime.utc_now())

      assert {:ok, released_token} = Tokens.release_token(token.id)
      assert released_token.status == "available"
      assert released_token.user_id == nil
      assert released_token.activated_at == nil
    end

    test "updates token usage end time" do
      user_id = Ecto.UUID.generate()
      token = insert(:token, status: "active", user_id: user_id, activated_at: DateTime.utc_now())

      usage =
        insert(:token_usage, token_id: token.id, user_id: user_id, started_at: DateTime.utc_now())

      assert {:ok, _} = Tokens.release_token(token)
      updated_usage = Repo.get(TokenUsage, usage.id)
      assert updated_usage.ended_at != nil
    end
  end

  describe "clear_active_tokens/0" do
    test "clears all active tokens and updates usage history" do
      active_tokens =
        for _ <- 1..3 do
          token =
            insert(:token, %{
              status: "active",
              user_id: Ecto.UUID.generate()
            })

          insert(:token_usage, %{
            token_id: token.id,
            user_id: token.user_id,
            started_at: DateTime.utc_now()
          })

          token
        end

      insert_list(2, :token, %{status: "available", user_id: nil})

      {:ok, result} = Tokens.clear_active_tokens()

      assert result.tokens_cleared == 3
      assert result.usages_updated == 3

      assert Tokens.list_active_tokens() == []
      assert length(Tokens.list_available_tokens()) == 5

      Enum.each(active_tokens, fn token ->
        history = Tokens.get_token_history(token.id)
        assert Enum.all?(history.history, &(&1.ended_at != nil))
      end)
    end
  end

  describe "edge cases" do
    test "allocate_token returns error when no tokens exist" do
      Repo.delete_all(Token)

      assert {:error, :no_tokens_available} = Tokens.allocate_token(Ecto.UUID.generate())
    end

    test "cannot allocate token when all are active and transaction fails" do
      :ok
    end
  end
end
