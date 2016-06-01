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
    list = []
    list = add_right(Permission.Camera.can_snapshot?(user, camera), list, "snapshot")
    list = add_right(Permission.Camera.can_view?(user, camera), list, "view")
    list = add_right(Permission.Camera.can_edit?(user, camera), list, "edit")
    list = add_right(Permission.Camera.can_delete?(user, camera), list, "delete")
    list = add_right(Permission.Camera.can_list?(user, camera), list, "list")
    Enum.join(list, ",")
  end
  def get_rights(kind, user, camera) do
    ["snapshot", "list"]
    |> Enum.join(",")
  end

  defp add_right(false, list, right), do: list
  defp add_right(true, list, right) do
    List.insert_at(list, -1, right)
  end

  def changeset(model, params \\ :invalid) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
