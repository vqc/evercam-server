defmodule EvercamMedia.Snapshot.DBHandler do
  @moduledoc """
  This module should ideally delegate all the updates to be made to the database
  on various events to another module.

  Right now, this is a extracted and slightly modified from the previous version of
  worker.

  These are the list of tasks for the db handler
    * Create an entry in the snapshots table for each retrived snapshots
    * Update the CameraActivity table whenever there is a change in the camera status
    * Update the status and last_polled_at values of Camera table
    * Update the thumbnail_url of the Camera table - This was done in the previous
    version and not now. This update can be avoided if thumbnails can be dynamically
    served.
  """
  use GenEvent
  require Logger
  alias EvercamMedia.Repo
  alias EvercamMedia.SnapshotRepo
  alias EvercamMedia.S3


  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data

    case previous_image = ConCache.get(:cache, camera_exid) do
      %{} ->
        Logger.info "Going to calculate MD"
        motion_level = EvercamMedia.MotionDetection.Lib.compare(image,previous_image[:image])
        Logger.info "calculated motion level is #{motion_level}"
      _ ->
        Logger.info "No previous image found in the cache"
        motion_level = nil
    end


    spawn fn ->
      try do
        update_camera_status("#{camera_exid}", timestamp, true)
        |> save_snapshot_record(timestamp, motion_level)
      rescue
        _error ->
          error_handler(_error)
      end
    end
    note = "Evercam Proxy"
    ConCache.put(:cache, camera_exid, %{image: image, timestamp: timestamp, notes: note})
    {:ok, state}
  end

  def handle_event({:snapshot_error, data}, state) do
    {camera_exid, timestamp, error} = data
    if is_map(error) do
      message = Map.get(error, :message)
    else
      message = nil
    end
    case message do
      "req_timedout" ->
        Logger.info "Request timeout for camera #{camera_exid}"
      "econnrefused" ->
        Logger.info "Connection refused for camera #{camera_exid}"
        update_camera_status("#{camera_exid}", timestamp, false)
       _ ->
         Logger.warn "Unhandled HTTPError #{inspect error}"
    end
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def update_camera_status(camera_exid, timestamp, status) do
    #TODO Improve the db queries here
    {:ok, datetime} = Calendar.DateTime.Parse.unix!(timestamp)
               |> Calendar.DateTime.to_erl
               |> Ecto.DateTime.cast
    camera = Repo.one! Camera.by_exid(camera_exid)
    camera_is_online = camera.is_online
    camera = construct_camera(camera, datetime, status, camera_is_online == status)
    file_path = "/#{camera.exid}/snapshots/#{timestamp}.jpg"
    camera = %{camera | thumbnail_url: S3.file_url(file_path)}
    Repo.update camera

    unless camera_is_online == status do
      log_camera_status(camera.id, status, datetime)
      Exq.Enqueuer.enqueue(
        :exq_enqueuer,
        "cache",
        "Evercam::CacheInvalidationWorker",
        camera_exid
      )
    end
    camera
  end

  def log_camera_status(camera_id, true, datetime) do
    Repo.insert %CameraActivity{camera_id: camera_id, action: "online", done_at: datetime}
  end

  def log_camera_status(camera_id, false, datetime) do
    Repo.insert %CameraActivity{camera_id: camera_id, action: "offline", done_at: datetime}
    camera = Repo.one! Camera.by_id_with_owner(camera_id)
    if camera.owner.username == "vq" || camera.owner.username == "marco" do
      EvercamMedia.UserMailer.camera_offline(camera.owner, camera)
    end
  end

  defp save_snapshot_record(camera, timestamp, motion_level) do
    {:ok, datetime} = Calendar.DateTime.Parse.unix!(timestamp)
               |> Calendar.DateTime.to_erl
               |> Ecto.DateTime.cast
    SnapshotRepo.insert %Snapshot{camera_id: camera.id, data: "S3", notes: "Evercam Proxy", motionlevel: motion_level, created_at: datetime}
  end

  defp construct_camera(camera, datetime, _, true) do
    %{camera | last_polled_at: datetime}
  end

  defp construct_camera(camera, datetime, false, false) do
    %{camera | last_polled_at: datetime, is_online: false}
  end

  defp construct_camera(camera, datetime, true, false) do
    %{camera | last_polled_at: datetime, is_online: true, last_online_at: datetime}
  end

  defp error_handler(error) do
    Logger.info inspect(error)
    Logger.info Exception.format_stacktrace System.stacktrace
  end
end
