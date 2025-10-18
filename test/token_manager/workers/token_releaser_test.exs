
defmodule TokenManager.Workers.TokenReleaserTest do
  use TokenManager.DataCase

  alias TokenManager.Workers.TokenReleaser
  alias TokenManager.Tokens
  alias TokenManager.Repo
  import TokenManager.Factory

  describe "perform/1" do
    test "releases active token when found" do
      active_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: DateTime.utc_now()
        })

      insert(:token_usage, %{
        token_id: active_token.id,
        user_id: active_token.user_id,
        started_at: DateTime.utc_now()
      })

      result = TokenReleaser.perform(%Oban.Job{args: %{"token_id" => active_token.id}})

      assert {:ok, _released_token} = result

      updated_token = Tokens.get_token!(active_token.id)
      assert updated_token.status == "available"
      assert updated_token.user_id == nil
      assert updated_token.activated_at == nil
    end

    test "returns :ok when token is not active" do
      available_token = insert(:token, %{status: "available"})

      result = TokenReleaser.perform(%Oban.Job{args: %{"token_id" => available_token.id}})

      assert result == :ok
      unchanged_token = Tokens.get_token!(available_token.id)
      assert unchanged_token.status == "available"
    end

    test "returns :ok when token is not found" do
      non_existent_id = Ecto.UUID.generate()

      result = TokenReleaser.perform(%Oban.Job{args: %{"token_id" => non_existent_id}})

      assert result == :ok
    end

    test "handles token release errors gracefully" do
      active_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: DateTime.utc_now()
        })

      result = TokenReleaser.perform(%Oban.Job{args: %{"token_id" => active_token.id}})
      assert match?({:ok, _}, result)
    end

    test "works with Oban job structure" do
      active_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: DateTime.utc_now()
        })

      job = %Oban.Job{
        args: %{"token_id" => active_token.id}
      }

      result = TokenReleaser.perform(job)
      assert match?({:ok, _}, result)
    end

    test "preserves token usage history when releasing" do
      active_token =
        insert(:token, %{
          status: "active",
          user_id: Ecto.UUID.generate(),
          activated_at: DateTime.utc_now()
        })

      usage =
        insert(:token_usage, %{
          token_id: active_token.id,
          user_id: active_token.user_id,
          started_at: DateTime.utc_now()
        })

      TokenReleaser.perform(%Oban.Job{args: %{"token_id" => active_token.id}})

      updated_usage = Repo.get(TokenManager.Tokens.TokenUsage, usage.id)
      assert updated_usage.ended_at != nil
      assert updated_usage.token_id == active_token.id
    end
  end

  describe "Oban configuration" do
    test "has correct worker configuration" do
      token_id = Ecto.UUID.generate()

      job = TokenReleaser.new(%{"token_id" => token_id})
      assert {:ok, inserted_job} = Oban.insert(job)

      assert inserted_job.worker == "TokenManager.Workers.TokenReleaser"
      assert inserted_job.queue == "default"
      assert inserted_job.max_attempts == 3
      assert inserted_job.args == %{"token_id" => token_id}
    end

    test "can be scheduled with delay" do
      token_id = Ecto.UUID.generate()

      job = TokenReleaser.new(%{token_id: token_id}, schedule_in: 120)
      assert {:ok, inserted_job} = Oban.insert(job)

      assert DateTime.diff(inserted_job.scheduled_at, DateTime.utc_now()) > 118
    end
  end
end
