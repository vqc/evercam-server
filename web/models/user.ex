defmodule User do
  use EvercamMedia.Web, :model
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(username password firstname lastname email)
  @optional_fields ~w(api_id api_key country_id confirmed_at updated_at created_at)

  schema "users" do
    belongs_to :country, Country, foreign_key: :country_id
    has_many :cameras, Camera, foreign_key: :owner_id
    has_many :camera_shares, CameraShare
    has_many :access_tokens, AccessToken

    field :username, :string
    field :password, :string
    field :firstname, :string
    field :lastname, :string
    field :email, :string
    field :api_id, :string
    field :api_key, :string
    field :billing_id, :string
    field :token_expires_at, Ecto.DateTime
    field :stripe_customer_id, :string
    field :confirmed_at, Ecto.DateTime
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def get_by_api_keys("", ""), do: nil
  def get_by_api_keys(nil, _api_key), do: nil
  def get_by_api_keys(_api_id, nil), do: nil
  def get_by_api_keys(api_id, api_key) do
    ConCache.dirty_get_or_store(:users, "#{api_id}_#{api_key}", fn() ->
      by_api_keys(api_id, api_key)
    end)
  end

  def by_username_or_email(login) when login in["", nil], do: nil
  def by_username_or_email(login) do
    User
    |> where([u], u.username == ^login or u.email == ^login)
    |> Repo.one
  end

  def by_username(username) do
    User
    |> where(username: ^username)
    |> preload(:country)
    |> Repo.one
  end

  def by_api_keys(api_id, api_key) do
    User
    |> where(api_id: ^api_id)
    |> where(api_key: ^api_key)
    |> Repo.one
  end

  def with_access_to(camera_full) do
    User
    |> join(:inner, [u], cs in CameraShare)
    |> where([_, cs], cs.camera_id == ^camera_full.id)
    |> where([u, cs], u.id == cs.user_id)
    |> Repo.all
    |> Enum.into([camera_full.owner])
  end

  def get_country_attr(user, attr) do
    case user.country do
      nil -> ""
      country -> Map.get(country, attr)
    end
  end

  def get_fullname(nil), do: ""
  def get_fullname(user) do
    "#{user.firstname} #{user.lastname}"
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
    |> unique_constraint(:username, [name: :user_username_unique_index])
    |> unique_constraint(:email, [name: :user_email_unique_index])
    |> validate_format(:email, ~r/^.+@.+\..+$/)
  end
end
