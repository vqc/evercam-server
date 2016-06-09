defmodule EvercamMedia.CloudRecordingController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.ErrorView
  import EvercamMedia.Validation.CloudRecording
  alias EvercamMedia.Snapshot.WorkerSupervisor

  def show(conn, %{"id" => exid}) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         do: camera.cloud_recordings |> render_cloud_recording(conn)
  end

  def create(conn, %{"id" => exid} = params) do
    current_user = conn.assigns[:current_user]
    camera = Camera.by_exid_with_associations(exid)

    with :ok <- ensure_camera_exists(camera, exid, conn),
         :ok <- ensure_can_edit(current_user, camera, conn),
         :ok <- validate_params(params) |> ensure_params(conn)
    do
      cr_params = %{
        camera_id: camera.id,
        frequency: params["frequency"],
        storage_duration: params["storage_duration"],
        status: params["status"],
        schedule: get_json(params["schedule"])
      }

      cloud_recording = camera.cloud_recordings || %CloudRecording{}
      case cloud_recording |> CloudRecording.changeset(cr_params) |> Repo.insert_or_update do
        {:ok, cloud_recording} ->
          exid
          |> String.to_atom
          |> Process.whereis
          |> WorkerSupervisor.update_worker(camera)

          conn |> render("cloud_recording.json", %{cloud_recording: cloud_recording})
        {:error, changeset} ->
          conn |> put_status(404) |> render(ErrorView, "error.json", %{message: changeset})
      end
    end
  end

  defp ensure_camera_exists(nil, exid, conn) do
    conn
    |> put_status(404)
    |> render(ErrorView, "error.json", %{message: "Camera '#{exid}' not found!"})
  end
  defp ensure_camera_exists(camera, _id, _conn), do: :ok

  defp ensure_can_edit(current_user, camera, conn) do
    if Permission.Camera.can_edit?(current_user, camera) do
      :ok
    else
      conn |> put_status(403) |> render(ErrorView, "error.json", %{message: "You don't have sufficient rights for this."})
    end
  end

  defp ensure_params(:ok, _conn), do: :ok
  defp ensure_params({:invalid, message}, conn), do: json(conn, %{error: message})

  defp get_json(schedule) do
    case Poison.decode(schedule) do
      {:ok, json} -> json
    end
  end

  defp render_cloud_recording(nil, conn), do: conn |> render("show.json", %{cloud_recording: []})
  defp render_cloud_recording(cl, conn), do: conn |> render("cloud_recording.json", %{cloud_recording: cl})
end
