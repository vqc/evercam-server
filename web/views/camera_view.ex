defmodule EvercamMedia.CameraView do
  use EvercamMedia.Web, :view
  import Permissions.Camera, only: [is_owner?: 2]

  def render("show.json", %{camera: camera, user: user}) do
    %{cameras: render_many([camera], __MODULE__, "camera.json", user: user)}
  end

  def render("camera.json", %{camera: camera, user: user}) do
    %{
      id: camera.exid,
      name: camera.name,
      owned: is_owner?(user, camera),
      owner: camera.owner.username,
      vendor_id: Camera.get_vendor_attr(camera, :exid),
      vendor_name: Camera.get_vendor_attr(camera, :name),
      model_id: Camera.get_model_attr(camera, :exid),
      model_name: Camera.get_model_attr(camera, :name),
      created_at: format_timestamp(camera.created_at),
      updated_at: format_timestamp(camera.updated_at),
      last_polled_at: format_timestamp(camera.last_polled_at),
      last_online_at: format_timestamp(camera.last_online_at),
      is_online_email_owner_notification: camera.is_online_email_owner_notification,
      is_online: camera.is_online,
      is_public: camera.is_public,
      discoverable: camera.discoverable,
      timezone: Camera.get_timezone(camera),
      cam_username: Camera.username(camera),
      cam_password: Camera.password(camera),
      mac_address: camera.mac_address,
      location: Camera.get_location(camera),
    }
  end

  defp format_timestamp(ecto_datetime) do
    ecto_datetime
    |> Ecto.DateTime.to_erl
    |> Calendar.DateTime.from_erl!("Etc/UTC")
    |> Calendar.DateTime.Format.unix
  end
end
