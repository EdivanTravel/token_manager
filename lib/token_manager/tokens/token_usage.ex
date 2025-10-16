defmodule TokenManager.Tokens.TokenUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "token_usages" do
    field :token_id, :binary_id
    field :user_id, :binary_id
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    timestamps()
  end

  def changeset(token_usage, attrs) do
    token_usage
    |> cast(attrs, [:token_id, :user_id, :started_at, :ended_at])
    |> validate_required([:token_id, :user_id, :started_at])
  end
end
