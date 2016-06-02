defmodule EvercamMedia.CameraShareRequestView do
  use EvercamMedia.Web, :view

  def render("index.json", %{camera_share_requests: camera_share_requests}) do
    %{share_requests: render_many(camera_share_requests, __MODULE__, "camera_share_request.json")}
  end

  def render("camera_share_request.json", %{camera_share_request: camera_share_request}) do
    %{
      id: camera_share_request.key,
      camera_id: camera_share_request.camera.exid,
      user_id: camera_share_request.user.username,
      sharer_name: "#{camera_share_request.user.firstname} #{camera_share_request.user.lastname}",
      sharer_email: camera_share_request.user.email,
      email: camera_share_request.email,
      rights: camera_share_request.rights
    }
  end
end
