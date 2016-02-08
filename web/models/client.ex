defmodule Client do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(api_id api_key)
  @optional_fields ~w(name callback_uris settings)

  schema "clients" do
    has_many :access_tokens, AccessToken

    field :name, :string
    field :api_id, :string
    field :api_key, :string
    field :callback_uris, {:array, :string}
    field :settings, :string

    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def get_by_api_keys(api_id, api_key) do
    Client
    |> where([u], u.api_id == ^api_id)
    |> where([u], u.api_key == ^api_key)
    |> Repo.one
  end

  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:api_id, [name: "ux_clients_exid"])
  end
end
