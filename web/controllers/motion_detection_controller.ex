defmodule EvercamMedia.MotionDetectionController do
  use EvercamMedia.Web, :controller

  def show(conn, %{"id" => exid}) do
    caller = conn.assigns[:current_user]
    camera = exid |> String.downcase |> Camera.get_full

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- ensure_authorized(conn, caller, camera)
    do
      conn
      |> render("show.json", %{motion_detection: camera.motion_detections})
    end
  end

  defp camera_exists(conn, camera_exid, nil) do
    render_error(conn, 404, "The #{camera_exid} camera does not exist.")
  end
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp ensure_authorized(conn, user, camera) do
    case Permission.Camera.can_view?(user, camera) do
      true -> :ok
      false -> render_error(conn, 403, "Forbidden.")
    end
  end
end
