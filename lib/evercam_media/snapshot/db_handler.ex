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
  alias Calendar.DateTime
  alias Calendar.Strftime

  def handle_event({:got_snapshot, data}, state) do
    {camera_exid, timestamp, image} = data
    Logger.debug "[#{camera_exid}] [snapshot_success]"

    notes = "Evercam Proxy"
    camera = Camera.get_full(to_string(camera_exid))
    cached_response = ConCache.get(:cache, camera_exid)
    motion_level = calculate_motion_level(camera_exid, image, cached_response)

    spawn fn ->
      try do
        update_camera_status("#{camera_exid}", timestamp, true, true)
        |> save_snapshot_record(timestamp, motion_level, notes)
      rescue
        error ->
          Util.error_handler(error)
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

  def calculate_motion_level(_camera_exid, _image_1, nil), do: nil
  def calculate_motion_level(camera_exid, image_1, %{image: image_2}) do
    try do
      Logger.debug "[#{camera_exid}] [motion_detection] [calculating]"
      level = EvercamMedia.MotionDetection.Lib.compare(camera_exid, image_1, image_2)
      Logger.debug "[#{camera_exid}] [motion_detection] [calculated] [#{level}]"
      level
    rescue
      error ->
        Util.error_handler(error)
        nil
    end
  end

  def parse_snapshot_error(camera_exid, timestamp, error) do
    reason =
      case error do
        %CaseClauseError{} ->
          :bad_request
        %HTTPotion.HTTPError{} ->
          Map.get(error, :message) |> String.to_atom
        error when is_map(error) ->
          Map.get(error, :reason)
        _ ->
          error
      end
    handle_snapshot_error(camera_exid, timestamp, error, reason)
  end

  defp handle_snapshot_error(camera_exid, timestamp, error, reason) do
    case reason do
      :system_limit ->
        Logger.error "[#{camera_exid}] [snapshot_error] [system_limit] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :emfile ->
        Logger.error "[#{camera_exid}] [snapshot_error] [emfile] Traceback."
        Util.error_handler(error)
        [500, %{message: "Sorry, we dropped the ball."}]
      :bad_request ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [bad_request]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Bad request."}]
      :closed ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [closed]"
        [504, %{message: "Connection closed."}]
      :nxdomain ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [nxdomain]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Non-existant domain."}]
      :ehostunreach ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [ehostunreach]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "No route to host."}]
      :enetunreach ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [enetunreach]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Network unreachable."}]
      :timeout ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [timeout]"
        [504, %{message: "Camera response timed out."}]
      :connect_timeout ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [connect_timeout]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Connection to the camera timed out."}]
      :econnrefused ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [econnrefused]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Connection refused."}]
      :not_found ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [not_found]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Camera url is not found.", response: error[:response]}]
      :forbidden ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [forbidden]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Camera responded with a Forbidden message.", response: error[:response]}]
      :unauthorized ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [unauthorized]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Camera responded with a Unauthorized message.", response: error[:response]}]
      :device_error ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [device_error]"
        update_camera_status("#{camera_exid}", timestamp, false)
        [504, %{message: "Camera responded with a Device Error message.", response: error[:response]}]
      :device_busy ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [device_busy]"
        [502, %{message: "Camera responded with a Device Busy message.", response: error[:response]}]
      :not_a_jpeg ->
        Logger.debug "[#{camera_exid}] [snapshot_error] [not_a_jpeg]"
        [504, %{message: "Camera didn't respond with an image.", response: error[:response]}]
      _reason ->
        Logger.info "[#{camera_exid}] [snapshot_error] [unhandled] #{inspect error}"
        [500, %{message: "Sorry, we dropped the ball."}]
    end
  end

  def update_camera_status(camera_exid, timestamp, status, update_thumbnail? \\ false) do
    camera = Camera.get_full(camera_exid)

    if update_thumbnail? && stale_thumbnail?(camera.thumbnail_url, timestamp) do
      update_thumbnail(camera, timestamp)
    end

    if camera.is_online != status do
      datetime =
        Calendar.DateTime.Parse.unix!(timestamp)
        |> Calendar.DateTime.to_erl
        |> Ecto.DateTime.cast!
      params = construct_camera(datetime, status, camera.is_online == status)
      changeset = Camera.changeset(camera, params)
      Repo.update!(changeset)
      ConCache.delete(:camera, camera_exid)
      camera = Camera.get_full(camera_exid)
      invalidate_camera_cache(camera)
      log_camera_status(camera, status, datetime)
    end

    camera
  end

  def update_thumbnail(camera, timestamp) do
    params = %{thumbnail_url: generate_thumbnail_url(camera.exid, timestamp)}
    changeset = Camera.changeset(camera, params)
    Repo.update(changeset)
    ConCache.delete(:camera, camera.exid)
  end

  def stale_thumbnail?(nil, _), do: true
  def stale_thumbnail?(thumbnail_url, timestamp) do
    on_s3? = String.match?(thumbnail_url, ~r/AWSAccessKeyId/)
    thumbnail_timestamp = parse_thumbnail_url(thumbnail_url, on_s3?)
    (timestamp - thumbnail_timestamp) > 300
  end

  def parse_thumbnail_url(url, true) do
    Regex.run(~r/snapshots\/(.+)\.jpg/, url)
    |> List.last
    |> String.to_integer
  end

  def parse_thumbnail_url(url, false) do
    Regex.run(~r/thumbnail\/(.+)\?token/, url)
    |> List.last
    |> Calendar.NaiveDateTime.Parse.iso8601
    |> elem(1)
    |> Calendar.DateTime.from_naive("Etc/UTC")
    |> elem(1)
    |> Calendar.DateTime.Format.unix
  end

  def invalidate_camera_cache(camera) do
    Exq.enqueue(Exq, "cache", "Evercam::CacheInvalidationWorker", camera.exid)
  end

  def log_camera_status(camera, true, datetime) do
    parameters = %{camera_id: camera.id, action: "online", done_at: datetime}
    changeset = CameraActivity.changeset(%CameraActivity{}, parameters)
    SnapshotRepo.insert(changeset)
    if camera.is_online_email_owner_notification do
      EvercamMedia.UserMailer.camera_online(camera.owner, camera)
    end
  end

  def log_camera_status(camera, false, datetime) do
    parameters = %{camera_id: camera.id, action: "offline", done_at: datetime}
    changeset = CameraActivity.changeset(%CameraActivity{}, parameters)
    SnapshotRepo.insert(changeset)
    if camera.is_online_email_owner_notification do
      EvercamMedia.UserMailer.camera_offline(camera.owner, camera)
    end
  end

  def save_snapshot_record(camera, timestamp, motion_level, notes) do
    datetime =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.DateTime.to_erl
      |> Ecto.DateTime.cast!
    snapshot_timestamp =
      Calendar.DateTime.Parse.unix!(timestamp)
      |> Calendar.Strftime.strftime!("%Y%m%d%H%M%S%f")

    snapshot_id = Util.format_snapshot_id(camera.id, snapshot_timestamp)
    parameters = %{camera_id: camera.id, notes: notes, motionlevel: motion_level, created_at: datetime, snapshot_id: snapshot_id}
    changeset = Snapshot.changeset(%Snapshot{}, parameters)
    SnapshotRepo.insert(changeset)
  end

  def generate_thumbnail_url(camera_exid, timestamp) do
    iso_timestamp =
      timestamp
      |> DateTime.Parse.unix!
      |> Strftime.strftime!("%Y-%m-%dT%H:%M:%S.%f")
      |> String.slice(0, 23)
      |> String.ljust(23, ?0)
      |> String.ljust(24, ?Z)
    token = Util.encode([camera_exid, iso_timestamp])
    EvercamMedia.Endpoint.static_url <> "/v1/cameras/#{camera_exid}/thumbnail/#{iso_timestamp}?token=#{token}"
  end

  defp construct_camera(datetime, online_status, online_status_unchanged) do
    camera_params(datetime, online_status, online_status_unchanged)
  end

  defp camera_params(datetime, _, true) do
    %{updated_at: datetime, last_polled_at: datetime}
  end

  defp camera_params(datetime, false, false) do
    %{updated_at: datetime, last_polled_at: datetime, is_online: false}
  end

  defp camera_params(datetime, true, false) do
    %{updated_at: datetime, last_polled_at: datetime, is_online: true, last_online_at: datetime}
  end
end
