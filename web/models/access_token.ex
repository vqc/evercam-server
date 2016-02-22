defmodule AccessToken do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(grantor_id is_revoked expires_at request)
  @optional_fields ~w(grantee_id refresh)

  schema "access_tokens" do
    belongs_to :user, User, foreign_key: :user_id
    belongs_to :client, Client, foreign_key: :client_id
    belongs_to :grantor, User, foreign_key: :grantor_id
    has_many :rights, AccessRight

    field :is_revoked, :boolean, null: false
    field :expires_at, Ecto.DateTime
    field :request, :string, null: false
    field :refresh, :string
    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def active_token_for(user_id) do
    AccessToken
    |> where([t], t.user_id == ^user_id)
    |> where([t], t.is_revoked == false)
    |> where([t], t.expires_at > ^Ecto.DateTime.utc)
    |> Repo.first
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:request, on: EvercamMedia.Repo)
  end
end
