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
    timestamps(inserted_at: :created_at, type: Ecto.DateTime, default: Ecto.DateTime.utc)
  end

  def rights_list("full"), do: ["snapshot", "view", "edit", "list"]
  def rights_list(_), do: ["snapshot", "list"]

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
    |> Repo.insert!
    AccessRight.grant(sharee, camera, rights)
  end

  def to_rights_list(rights) do
    rights
    |> String.downcase
    |> String.split(",", trim: true)
    |> Enum.map(fn(right) -> String.strip(right) end)
    |> Enum.filter(fn(right) -> AccessRight.valid_right_name?(right) end)
  end

  def delete_share(user, camera) do
    rights = AccessRight.camera_rights
    AccessRight.revoke(user, camera, rights)
    CameraShare
    |> where(camera_id: ^camera.id)
    |> where(user_id: ^user.id)
    |> Repo.delete_all
  end

  def camera_shares(camera) do
    CameraShare
    |> where(camera_id: ^camera.id)
    |> preload(:user)
    |> preload(:sharer)
    |> preload(:camera)
    |> preload([camera: :access_rights])
    |> preload([camera: [access_rights: :access_token]])
    |> Repo.all
  end

  def user_camera_share(camera, user) do
    CameraShare
    |> where(camera_id: ^camera.id)
    |> where(user_id: ^user.id)
    |> preload(:user)
    |> preload(:sharer)
    |> preload(:camera)
    |> preload([camera: :access_rights])
    |> preload([camera: [access_rights: :access_token]])
    |> Repo.all
  end

  def get_rights("private", user, camera) do
    ["snapshot", "list", "view", "edit", "delete"]
    |> Enum.filter(fn(right) -> Permission.Camera.can_access?(right, user, camera) end)
    |> Enum.join(",")
  end

  def get_rights("public", _user, _camera) do
    ["snapshot", "list"]
    |> Enum.join(",")
  end

  def delete_by_user(user_id) do
    CameraShare
    |> where(user_id: ^user_id)
    |> Repo.delete_all
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
