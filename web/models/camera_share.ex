defmodule CameraShare do
  use EvercamMedia.Web, :model
  alias EvercamMedia.Repo
  import Ecto.Query

  @required_fields ~w(camera_id user_id kind)
  @optional_fields ~w(sharer_id message updated_at created_at)
  @kind %{private: "private", public: "public"}

  schema "camera_shares" do
    belongs_to :camera, Camera
    belongs_to :user, User
    belongs_to :sharer, User, foreign_key: :sharer_id

    field :kind, :string
    field :message, :string
    field :updated_at, Ecto.DateTime, default: Ecto.DateTime.utc
    field :created_at, Ecto.DateTime, default: Ecto.DateTime.utc
  end

  def create_share(camera, sharee, sharer, rights) do
    share_changeset =
      %{
        camera_id: camera.id,
        user_id: sharee.id,
        sharer_id: sharer.id,
        kind: @kind.private
      }
    %CameraShare{}
    |> changeset(share_changeset)
    |> Repo.insert
    AccessRight.grant(sharee, camera, rights)
  end

  def generate_rights_list(permissions) do
    if permissions == "full" do
      ["snapshot", "view", "edit", "list"]
    else
      ["snapshot", "list"]
    end
  end

  def to_rights_list(rights) do
    rights
    |> String.downcase
    |> String.split(",", trim: true)
    |> Enum.map(&String.strip/1)
    |> Enum.reject(fn(right) -> !AccessRight.valid_right_name?(right) end)
  end

  def delete_share(user, camera) do
    rights = AccessRight.camera_rights
    AccessRight.revoke(user, camera, rights)
    CameraShare
    |> where(camera_id: ^camera.id)
    |> where(user_id: ^user.id)
    |> Repo.delete_all
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
