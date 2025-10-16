defmodule TokenManager.Tokens.Token do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Phoenix.Param, key: :id}
  schema "tokens" do
    field :token, Ecto.UUID
    field :status, :string, default: "available"
    field :activated_at, :utc_datetime
    field :user_id, :binary_id

    timestamps()
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token, :status, :activated_at, :user_id])
    |> validate_required([:token, :status])
  end
end
