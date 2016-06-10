defmodule EvercamMedia.CameraShareRequestView do
  use EvercamMedia.Web, :view

  def render("index.json", %{camera_share_requests: camera_share_requests}) do
    %{share_requests: render_many(camera_share_requests, __MODULE__, "camera_share_request.json")}
  end

  def render("camera_share_request.json", %{camera_share_request: camera_share_request}) do
    %{
      id: camera_share_request.key,
      camera_id: camera_share_request.camera.exid,
      user_id: CameraShareRequest.get_sharer_username(camera_share_request),
      sharer_name: CameraShareRequest.get_sharer_fullname(camera_share_request),
      sharer_email: CameraShareRequest.get_sharer_email(camera_share_request),
      email: camera_share_request.email,
      rights: camera_share_request.rights
    }
  end
end
