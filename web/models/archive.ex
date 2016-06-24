defmodule Archive do
  use EvercamMedia.Web, :model
  import Ecto.Changeset
  import Ecto.Query
  alias EvercamMedia.Repo

  @required_fields ~w(title exid from_date to_date requested_by camera_id)
  @optional_fields ~w(status embed_time public timezone)

  schema "archives" do
    belongs_to :camera, Camera, foreign_key: :camera_id
    belongs_to :user, User, foreign_key: :requested_by

    field :exid, :string
    field :title, :string
    field :from_date, Ecto.DateTime
    field :to_date, Ecto.DateTime
    field :status, :integer
    field :embed_time, :boolean
    field :public, :boolean
    field :frames, :integer
    timestamps(inserted_at: :created_at, updated_at: false, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def by_exid(exid) do
    Archive
    |> where(exid: ^exid)
    |> preload(:camera)
    |> preload(:user)
    |> Repo.one
  end

  def delete_by_exid(exid) do
    Archive
    |> where(exid: ^exid)
    |> Repo.delete_all
  end

  def get_all_with_associations(query \\ Archive) do
    query
    |> preload(:camera)
    |> preload(:user)
    |> Repo.all
  end

  def by_camera_id(query, camera_id) do
    query
    |> where(camera_id: ^camera_id)
  end

  def with_status_if_given(query, nil), do: query
  def with_status_if_given(query, status) do
    query
    |> where(status: ^status)
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
