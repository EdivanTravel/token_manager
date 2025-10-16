defmodule TokenManager.Repo.Migrations.CreateTokens do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token, :uuid, null: false
      add :status, :string, default: "available", null: false
      add :activated_at, :utc_datetime
      add :user_id, :uuid

      timestamps()
    end

    create unique_index(:tokens, [:token])
  end
end
