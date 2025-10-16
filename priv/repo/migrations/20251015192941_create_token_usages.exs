defmodule TokenManager.Repo.Migrations.CreateTokenUsages do
  use Ecto.Migration

  def change do
    create table(:token_usages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :token_id, references(:tokens, type: :uuid), null: false
      add :user_id, :uuid, null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps()
    end

    create index(:token_usages, [:token_id])
    create index(:token_usages, [:user_id])
  end
end
