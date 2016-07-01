defmodule EvercamMedia.CameraShareRequestController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.CameraShareRequestView

  def show(conn, %{"id" => exid} = params) do
    caller = conn.assigns[:current_user]
    camera = exid |> String.downcase |> Camera.get_full
    status = parse_status(params["status"])

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- caller_has_permission(conn, caller, camera)
    do
      share_requests = CameraShareRequest.by_camera_and_status(camera, status)
      conn
      |> render(CameraShareRequestView, "index.json", %{camera_share_requests: share_requests})
    end
  end

  def update(conn, %{"id" => exid, "email" => email, "rights" => rights}) do
    caller = conn.assigns[:current_user]
    camera = exid |> String.downcase |> Camera.get_full

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- caller_has_permission(conn, caller, camera),
         {:ok, share_request} <- share_request_exists(conn, email, camera)
    do
      share_request
      |> CameraShareRequest.update_changeset(%{rights: rights})
      |> Repo.update
      |> case do
        {:ok, camera_share_request} ->
          conn
          |> render(CameraShareRequestView, "show.json", %{camera_share_requests: camera_share_request})
        {:error, changeset} ->
          conn
          |> render_error(400, Util.parse_changeset(changeset))
      end
    end
  end

  def cancel(conn, %{"id" => exid, "email" => email}) do
    caller = conn.assigns[:current_user]
    camera = exid |> String.downcase |> Camera.get_full

    with :ok <- camera_exists(conn, exid, camera),
         :ok <- caller_has_permission(conn, caller, camera),
         {:ok, share_request} <- share_request_exists(conn, email, camera)
    do
      params = %{rights: share_request.rights, status: CameraShareRequest.status.cancelled}

      share_request
      |> CameraShareRequest.update_changeset(params)
      |> Repo.update

      json(conn, %{})
    end
  end

  defp caller_has_permission(conn, user, camera) do
    if Permission.Camera.can_edit?(user, camera) do
      :ok
    else
      render_error(conn, 401, "Unauthorized.")
    end
  end

  defp share_request_exists(conn, email, camera) do
    case CameraShareRequest.get_pending_request(camera.id, email) do
      nil -> render_error(conn, 404, "Share request not found.")
      %CameraShareRequest{} = camera_share_request -> {:ok, camera_share_request}
    end
  end

  defp camera_exists(conn, camera_exid, nil), do: render_error(conn, 404, "The #{camera_exid} camera does not exist.")
  defp camera_exists(_conn, _camera_exid, _camera), do: :ok

  defp parse_status(value) when value in [nil, ""], do: nil
  defp parse_status(value) do
    value
    |> String.downcase
    |> CameraShareRequest.get_status
  end
end
