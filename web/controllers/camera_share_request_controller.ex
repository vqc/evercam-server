defmodule EvercamMedia.CameraShareRequestController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraShareRequestView
  alias EvercamMedia.ErrorView

  def show(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.get_full(exid)
    status = parse_status(params["status"])

    with :ok <- is_authorized(conn, current_user),
         :ok <- camera_exists(conn, exid, camera)
    do
      share_requests = CameraShareRequest.by_camera_and_status(camera, status)
      conn
      |> render(CameraShareRequestView, "index.json", %{camera_share_requests: share_requests})
    end
  end

  defp is_authorized(conn, nil) do
    conn
    |> put_status(401)
    |> render(ErrorView, "error.json", %{message: "Unauthorized."})
  end
  defp is_authorized(_conn, _user), do: :ok

  defp camera_exists(conn, camera_exid, nil) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "The #{camera_exid} camera does not exist."})
  end
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp parse_status(value) when value in [nil, ""], do: nil
  defp parse_status(value) do
    value
    |> String.downcase
    |> CameraShareRequest.get_status
  end
end
