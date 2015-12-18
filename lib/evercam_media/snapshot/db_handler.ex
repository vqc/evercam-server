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
  alias EvercamMedia.Util


  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    notes = "Evercam Proxy"
    Logger.debug "[#{camera_exid}] [snapshot_success]"

    case previous_image = ConCache.get(:cache, camera_exid) do
      %{} ->
        Logger.debug "Going to calculate MD"
        motion_level = EvercamMedia.MotionDetection.Lib.compare(image,previous_image[:image])
        Logger.debug "calculated motion level is #{motion_level}"
      _ ->
        Logger.debug "No previous image found in the cache"
        motion_level = nil
    end

    spawn fn ->
      try do
        update_camera_status("#{camera_exid}", timestamp, true, true)
        |> save_snapshot_record(timestamp, motion_level, notes)
      rescue
        _error ->
          Util.error_handler(_error)
      end
    end
    ConCache.put(:cache, camera_exid, %{image: image, timestamp: timestamp, notes: notes})
    {:ok, state}
  end

  def handle_event({:snapshot_error, data}, state) do
    {camera_exid, timestamp, error} = data
    parse_snapshot_error(camera_exid, timestamp, error)
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  def parse_snapshot_error(camera_exid, timestamp, error) do
    if is_map(error) do
      reason = Map.get(error, :reason)
    else
      reason = error
    end
    case reason do
      :system_limit ->
        Logger.error "[#{camera_exid}] [snapshot_error] [system_limit] Traceback."
        Util.error_handler(error)
      :closed ->
        Logger.error "[#{camera_exid}] [snapshot_error] [closed] Traceback."
        Util.error_handler(error)
      :emfile ->
        Logger.error "[#{camera_exid}] [snapshot_error] [emfile] Traceback."
        Util.error_handler(error)
      :nxdomain ->
        pid = camera_exid |> Process.whereis
        Logger.info "[#{camera_exid}] [snapshot_error] [nxdomain]"
        update_camera_status("#{camera_exid}", timestamp, false)
      :ehostunreach ->
        Logger.info "[#{camera_exid}] [snapshot_error] [ehostunreach]"
        update_camera_status("#{camera_exid}", timestamp, false)
      :enetunreach ->
        pid = camera_exid |> Process.whereis
        Logger.info "[#{camera_exid}] [snapshot_error] [enetunreach]"
        update_camera_status("#{camera_exid}", timestamp, false)
      :timeout ->
        Logger.info "[#{camera_exid}] [snapshot_error] [timeout]"
      :connect_timeout ->
        Logger.info "[#{camera_exid}] [snapshot_error] [connect_timeout]"
        update_camera_status("#{camera_exid}", timestamp, false)
      :econnrefused ->
        Logger.info "[#{camera_exid}] [snapshot_error] [econnrefused]"
        update_camera_status("#{camera_exid}", timestamp, false)
      "Response not a jpeg image" ->
        Logger.info "[#{camera_exid}] [snapshot_error] [not_a_jpeg]"
      _ ->
        Logger.info "[#{camera_exid}] [snapshot_error] [unhandled] #{inspect error}"
    end
  end

  def update_camera_status(camera_exid, timestamp, status, update_thumbnail? \\ false) do
    #TODO Improve the db queries here
    {:ok, datetime} =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.DateTime.to_erl
      |> Ecto.DateTime.cast
    camera = Repo.one! Camera.by_exid(camera_exid)
    camera_is_online = camera.is_online
    camera = construct_camera(camera, datetime, status, camera_is_online == status)
    if status == true && update_thumbnail? do
      file_path = "/#{camera.exid}/snapshots/#{timestamp}.jpg"
      camera = %{camera | thumbnail_url: Util.s3_file_url(file_path)}
    end
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
    SnapshotRepo.insert %CameraActivity{camera_id: camera_id, action: "online", done_at: datetime}
  end

  def log_camera_status(camera_id, false, datetime) do
    SnapshotRepo.insert %CameraActivity{camera_id: camera_id, action: "offline", done_at: datetime}
    camera = Repo.one! Camera.by_id_with_owner(camera_id)
    if camera.owner.username == "vinniequinn" || camera.owner.username == "marco" do
      EvercamMedia.UserMailer.camera_offline(camera.owner, camera)
    end
  end

  def save_snapshot_record(camera, timestamp, motion_level, notes) do
    {:ok, datetime} =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.DateTime.to_erl
      |> Ecto.DateTime.cast
    {:ok, snapshot_timestamp} =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.Strftime.strftime "%Y%m%d%H%M%S%f"
    snapshot_id = Util.format_snapshot_id(camera.id, snapshot_timestamp)
    SnapshotRepo.insert(%Snapshot{camera_id: camera.id, notes: notes, motionlevel: motion_level, created_at: datetime, snapshot_id: snapshot_id})
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
end
