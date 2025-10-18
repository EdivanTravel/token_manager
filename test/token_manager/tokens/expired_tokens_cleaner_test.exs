defmodule TokenManager.Tokens.ExpiredTokensCleanerTest do
  use TokenManager.DataCase

  alias TokenManager.Tokens.ExpiredTokensCleaner
  alias TokenManager.Tokens
  alias TokenManager.Repo
  import TokenManager.Factory

  describe "perform/1" do
    test "releases expired tokens and returns success count" do
      expired_time = DateTime.add(DateTime.utc_now(), -121, :second)

      expired_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: expired_time
        })

      insert(:token_usage, %{
        token_id: expired_token.id,
        user_id: expired_token.user_id,
        started_at: expired_time
      })

      valid_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: DateTime.utc_now()
        })

      available_token = insert(:token, %{status: "available"})

      result = ExpiredTokensCleaner.perform(%Oban.Job{})

      assert result.cleaned == 1
      assert length(result.results) == 1
      assert {:ok, expired_token.id} in result.results
      assert Tokens.get_token!(expired_token.id).status == "available"
      assert Tokens.get_token!(expired_token.id).user_id == nil
      assert Tokens.get_token!(expired_token.id).activated_at == nil
      assert Tokens.get_token!(valid_token.id).status == "active"
      assert Tokens.get_token!(valid_token.id).user_id != nil
      assert Tokens.get_token!(available_token.id).status == "available"
    end

    test "handles multiple expired tokens correctly" do
      expired_time = DateTime.add(DateTime.utc_now(), -300, :second)

      expired_tokens =
        for _ <- 1..3 do
          token =
            insert(:token, %{
              status: "active",
              user_id: Ecto.UUID.generate(),
              activated_at: expired_time
            })

          insert(:token_usage, %{
            token_id: token.id,
            user_id: token.user_id,
            started_at: expired_time
          })

          token
        end

      result = ExpiredTokensCleaner.perform(%Oban.Job{})
      assert result.cleaned == 3
      assert length(result.results) == 3

      Enum.each(expired_tokens, fn token ->
        assert Tokens.get_token!(token.id).status == "available"
      end)
    end

    test "returns empty results when no expired tokens exist" do
      insert(:token, %{
        status: "active",
        user_id: Ecto.UUID.generate(),
        activated_at: DateTime.utc_now()
      })

      insert(:token, %{status: "available"})

      result = ExpiredTokensCleaner.perform(%Oban.Job{})
      assert result.cleaned == 0
      assert result.results == []
    end

    test "handles tokens that are exactly at expiration boundary" do
      boundary_time = DateTime.add(DateTime.utc_now(), -120, :second)

      boundary_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: boundary_time
        })

      result = ExpiredTokensCleaner.perform(%Oban.Job{})

      assert result.cleaned == 0
      assert Tokens.get_token!(boundary_token.id).status == "active"
    end

    test "handles release errors gracefully" do
      expired_time = DateTime.add(DateTime.utc_now(), -121, :second)

      expired_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: expired_time
        })

      original_release = &Tokens.release_token/1

      try do
        result = ExpiredTokensCleaner.perform(%Oban.Job{})

        assert result.cleaned == 1
        assert {:ok, expired_token.id} in result.results
      after
      end
    end

    test "worker has correct Oban configuration" do
      job = ExpiredTokensCleaner.new(%{})
      assert {:ok, inserted_job} = Oban.insert(job)

      assert inserted_job.worker == "TokenManager.Tokens.ExpiredTokensCleaner"
      assert inserted_job.queue == "default"
      assert inserted_job.max_attempts == 1
    end
  end

  describe "integration with Oban" do
    test "can be scheduled as a periodic job" do
      expired_time = DateTime.add(DateTime.utc_now(), -121, :second)

      _expired_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: expired_time
        })

      job = ExpiredTokensCleaner.new(%{}, schedule_in: 10)
      assert {:ok, _job} = Oban.insert(job)
    end
  end

  test "query finds only expired active tokens" do
    expired_time = DateTime.add(DateTime.utc_now(), -121, :second)

    expired_active =
      insert(:token, %{
        status: "active",
        user_id: Ecto.UUID.generate(),
        activated_at: expired_time
      })

    _valid_active =
      insert(:token, %{
        status: "active",
        user_id: Ecto.UUID.generate(),
        activated_at: DateTime.utc_now()
      })

    _available = insert(:token, %{status: "available"})

    query_time = DateTime.utc_now() |> DateTime.add(-120, :second)

    expired_tokens =
      Repo.all(
        from t in TokenManager.Tokens.Token,
          where: t.status == "active" and t.activated_at < ^query_time
      )

    assert length(expired_tokens) == 1
    assert hd(expired_tokens).id == expired_active.id
  end
end
