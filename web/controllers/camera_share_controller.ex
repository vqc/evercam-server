defmodule EvercamMedia.CameraShareController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraShareView
  alias EvercamMedia.ErrorView

  def show(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    user = User.by_username_or_email(params["user_id"])

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- user_has_permission(conn, current_user, camera),
         :ok <- user_exists(conn, params["user_id"], user),
         :ok <- user_can_list(conn, current_user, camera, params["user_id"])
    do
      shares =
        if user do
          CameraShare.user_camera_share(camera, user)
        else
          CameraShare.camera_shares(camera)
        end
      conn
      |> render(CameraShareView, "index.json", %{camera_shares: shares, camera: camera, user: current_user})
    end
  end

  defp camera_exists(conn, camera_exid, nil) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "The #{camera_exid} camera does not exist."})
  end
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp user_exists(_conn, nil, nil), do: :ok
  defp user_exists(conn, user_id, nil) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "User '#{user_id}' does not exist."})
  end
  defp user_exists(_conn, _user_id, _user), do: :ok

  defp user_has_permission(conn, user, camera) do
    if Permission.Camera.can_edit?(user, camera) do
      :ok
    else
      conn
      |> put_status(401)
      |> render(ErrorView, "error.json", %{message: "Unauthorized."})
    end
  end

  defp user_can_list(_conn, _user, _camera, nil), do: :ok
  defp user_can_list(conn, user, camera, user_id) do
    if !Permission.Camera.can_list?(user, camera) && (user.email != user_id && user.username != user_id) do
      conn
      |> put_status(401)
      |> render(ErrorView, "error.json", %{message: "Unauthorized."})
    else
      :ok
    end
  end
end
