defmodule EvercamMedia.CameraController do
  use EvercamMedia.Web, :controller
  alias Calendar.NaiveDateTime
  alias Calendar.Strftime
  alias EvercamMedia.Snapshot.Storage
  alias EvercamMedia.Snapshot.StreamerSupervisor
  alias EvercamMedia.Snapshot.WorkerSupervisor
  alias EvercamMedia.Snapshot.Worker
  alias EvercamMedia.Util

  def thumbnail(conn, %{"id" => exid, "timestamp" => iso_timestamp, "token" => token}) do
    # TODO: handle failed requests

    [token_exid, token_timestamp, _] = Util.decode_token(token)
    if exid != token_exid, do: raise "Invalid token."
    if iso_timestamp != token_timestamp, do: raise "Invalid token."

    camera = Camera.get(exid)
    snapshot_timestamp =
      iso_timestamp
      |> NaiveDateTime.Parse.iso8601
      |> elem(1)
      |> Strftime.strftime!("%Y%m%d%H%M%S%f")
      |> Util.format_snapshot_timestamp

    image = Storage.load(camera.exid, "#{camera.id}_#{snapshot_timestamp}")

    conn
    |> put_status(200)
    |> put_resp_header("content-type", "image/jpg")
    |> put_resp_header("access-control-allow-origin", "*")
    |> text(image)
  end

  def update(conn, %{"id" => exid, "token" => token}) do
    try do
      [token_exid, _timestamp, _] = Util.decode_token(token)
      if exid != token_exid, do: raise "Invalid token."

      Logger.info "Camera update for #{exid}"
      ConCache.delete(:camera, exid)
      camera = exid |> Camera.get
      worker = exid |> String.to_atom |> Process.whereis

      case worker do
        nil ->
          start_worker(camera)
        _ ->
          update_worker(worker, camera)
      end
      send_resp(conn, 200, "Camera update request received.")
    rescue
      _error ->
        send_resp(conn, 500, "Invalid token.")
    end
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
