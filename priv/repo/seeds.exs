alias TokenManager.Repo
alias TokenManager.Tokens.Token

Repo.delete_all(Token)

IO.puts("Creating 100 tokens...")

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

tokens =
  for _ <- 1..100 do
    %{
      id: Ecto.UUID.generate(),
      token: Ecto.UUID.generate(),
      status: "available",
      inserted_at: now,
      updated_at: now
    }
  end

{count, _} = Repo.insert_all(Token, tokens)

IO.puts("✅ Created #{count} tokens successfully!")
