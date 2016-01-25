defmodule EvercamMedia.CameraController do
  use EvercamMedia.Web, :controller
  alias EvercamMedia.Snapshot.StreamerSupervisor
  alias EvercamMedia.Snapshot.WorkerSupervisor
  alias EvercamMedia.Snapshot.Worker

  def update(conn, %{"id" => exid, "token" => _token}) do
    # TODO: authorize using owner's api credentials, not token
    Logger.info "Camera update for #{exid}"
    ConCache.delete(:camera, exid)
    camera =
      exid
      |> Camera.get
      |> Repo.preload(:cloud_recordings)
      |> Repo.preload([vendor_model: :vendor])
    worker =
      exid
      |> String.to_atom
      |> Process.whereis

    case worker do
      nil ->
        start_worker(camera)
      _ ->
        update_worker(worker, camera)
    end
    send_resp(conn, 200, "Camera update request received.")
  end

  defp start_worker(camera) do
    WorkerSupervisor.start_worker(camera)
  end

  defp update_worker(worker, camera) do
    case WorkerSupervisor.get_config(camera) do
      {:ok, settings} ->
        Logger.info "Updating worker for #{settings.config.camera_exid}"
        StreamerSupervisor.restart_streamer(camera.exid)
        Worker.update_config(worker, settings)
      {:error, _message} ->
        Logger.info "Skipping camera worker update as the host is invalid"
    end
  end
end
