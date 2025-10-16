alias TokenManager.Repo
alias TokenManager.Tokens.Token

for _ <- 1..100 do
  Repo.insert!(%Token{token: Ecto.UUID.generate(), status: "available"})
end
