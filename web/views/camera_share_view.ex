defmodule EvercamMedia.CameraShareView do
  use EvercamMedia.Web, :view

  def render("index.json", %{camera_shares: camera_shares, camera: camera, user: user}) do
    shares_json = %{shares: render_many(camera_shares, __MODULE__, "camera_share.json")}
    if Permission.Camera.can_edit?(user, camera) do
      shares_json |> Map.merge(privileged_camera_attributes(camera))
    else
      shares_json
    end
  end

  def render("camera_share.json", %{camera_share: camera_share}) do
    %{
      id: camera_share.id,
      camera_id: camera_share.camera.exid,
      sharer_id: CameraShare.get_sharer_username(camera_share),
      sharer_name: CameraShare.get_sharer_fullname(camera_share),
      sharer_email: CameraShare.get_sharer_email(camera_share),
      user_id: camera_share.user.username,
      fullname: User.fullname(camera_share.user),
      email: camera_share.user.email,
      kind: camera_share.kind,
      rights: CameraShare.get_rights(camera_share.kind, camera_share.user, camera_share.camera)
    }
  end

  defp privileged_camera_attributes(camera) do
    %{
      owner: %{
        email: camera.owner.email,
        username: camera.owner.username,
        fullname: User.fullname(camera.owner)
      }
    }
  end
end
